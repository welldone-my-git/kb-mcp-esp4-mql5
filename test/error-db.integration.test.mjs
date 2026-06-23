import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";

const callText = async (client, name, args = {}) => {
  const result = await client.callTool({ name, arguments: args });
  return {
    ...result,
    text: result.content?.[0]?.text ?? "",
  };
};

const extractExportedJson = (text) => {
  const match = text.match(/```json\n([\s\S]*?)\n```/);
  assert.ok(match, "expected fenced JSON export in manage_error_db output");
  return match[1];
};

test("error database MCP tools persist, rank, export, import, anonymize, and feed smart_query", async (t) => {
  const home = await mkdtemp(path.join(tmpdir(), "knowledge-mcp-errors-"));
  t.after(() => rm(home, { recursive: true, force: true }));

  process.env.HOME = home;
  const { server } = await import("../build/index.js");
  const { closeErrorDb } = await import("../build/error-db.js");

  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const client = new Client({ name: "knowledge-mcp-error-db", version: "1.0.0" });
  t.after(async () => {
    await client.close();
    await server.close();
    closeErrorDb();
  });

  await server.connect(serverTransport);
  await client.connect(clientTransport);

  const tools = await client.listTools();
  const toolNames = new Set(tools.tools.map((tool) => tool.name));
  for (const required of ["log_error", "list_common_errors", "manage_error_db", "smart_query"]) {
    assert.ok(toolNames.has(required), `missing MCP tool: ${required}`);
  }

  const emptyList = await callText(client, "list_common_errors");
  assert.match(emptyList.text, /错误数据库为空/);

  const emptyStats = await callText(client, "manage_error_db", { action: "stats" });
  assert.match(emptyStats.text, /总错误类型: 0/);
  assert.match(emptyStats.text, /总出现次数: 0/);
  assert.ok(existsSync(path.join(home, ".knowledge-mcp", "mql5_errors.db")));

  const firstLog = await callText(client, "log_error", {
    error_code: "E256",
    error_message: "undeclared identifier 'ResultCode'",
    file_path: "/private/accounts/live-ea.mq5",
    solution: "Use CTrade::ResultRetcode() after trade operations.",
    related_docs: JSON.stringify(["ctraderesultretcode.htm"]),
  });
  assert.match(firstLog.text, /错误已记录到数据库/);
  assert.match(firstLog.text, /出现次数: 1/);

  const duplicateLog = await callText(client, "log_error", {
    error_code: "E256",
    error_message: "undeclared identifier 'ResultCode'",
    solution: "Use trade.ResultRetcode() instead of ResultCode().",
  });
  assert.match(duplicateLog.text, /出现次数: 2/);

  await callText(client, "log_error", {
    error_code: "E100",
    error_message: "low frequency example",
    solution: "This lower-frequency error should be ranked after E256.",
  });

  const common = await callText(client, "list_common_errors", { limit: 2 });
  assert.match(common.text, /1\. E256 - undeclared identifier 'ResultCode'/);
  assert.match(common.text, /出现次数: 2/);
  assert.match(common.text, /2\. E100 - low frequency example/);

  const smartFromDb = await callText(client, "smart_query", {
    query: "error E256 undeclared identifier ResultCode",
    mode: "quick",
  });
  assert.match(smartFromDb.text, /从错误数据库找到解决方案/);
  assert.match(smartFromDb.text, /ResultRetcode/);
  assert.match(smartFromDb.text, /错误数据库/);

  const exportRaw = await callText(client, "manage_error_db", { action: "export" });
  assert.match(exportRaw.text, /错误数据库导出成功/);
  const exportedJson = extractExportedJson(exportRaw.text);
  const exported = JSON.parse(exportedJson);
  assert.equal(exported.length, 2);
  assert.ok(exported.some((record) => record.file_path === "/private/accounts/live-ea.mq5"));

  const exportAnonymized = await callText(client, "manage_error_db", {
    action: "export",
    anonymize: true,
  });
  assert.match(exportAnonymized.text, /隐私模式/);
  assert.doesNotMatch(exportAnonymized.text, /\/private\/accounts\/live-ea\.mq5/);
  const anonymized = JSON.parse(extractExportedJson(exportAnonymized.text));
  assert.ok(anonymized.every((record) => !("file_path" in record)));

  const importData = JSON.stringify([
    {
      error_code: "E256",
      error_message: "undeclared identifier 'ResultCode'",
      solution: "Imported solution should update existing records.",
      related_docs: JSON.stringify(["ctraderesultretcode.htm", "errorswarnings.htm"]),
      occurrence_count: 5,
      first_seen: "2024-01-01T00:00:00.000Z",
      last_seen: "2024-02-01T00:00:00.000Z",
    },
    {
      error_code: "E777",
      error_message: "imported error",
      solution: "Imported new error solution.",
      occurrence_count: 3,
      first_seen: "2024-01-01T00:00:00.000Z",
      last_seen: "2024-02-01T00:00:00.000Z",
    },
  ]);
  const imported = await callText(client, "manage_error_db", {
    action: "import",
    data: importData,
  });
  assert.match(imported.text, /新导入: 1 条/);
  assert.match(imported.text, /已更新: 1 条/);
  assert.match(imported.text, /总错误类型: 3/);
  assert.match(imported.text, /总出现次数: 9/);

  const stats = await callText(client, "manage_error_db", { action: "stats" });
  assert.match(stats.text, /总错误类型: 3/);
  assert.match(stats.text, /总出现次数: 9/);

  closeErrorDb();

  const statsAfterClose = await callText(client, "manage_error_db", { action: "stats" });
  assert.match(statsAfterClose.text, /总错误类型: 3/);
  assert.match(statsAfterClose.text, /总出现次数: 9/);
});
