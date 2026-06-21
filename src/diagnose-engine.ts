import type { DocEntry } from "./core/plugin.js";
import { getErrorDb } from "./error-db.js";
import { MIGRATION_HINTS } from "./utils.js";

export interface DiagnosisItem {
  location: string;
  severity: "error" | "warning";
  code: string;
  message: string;
  migration?: string;
  dbSolution?: string;
  docHint?: string;
}

export class DiagnoseEngine {
  private static LOG_LINE = /^(.+?)\((\d+),(\d+)\)\s*:\s*(error|warning)\s+(\d+):\s*(.+)$/im;
  private static LOG_LINE_G = /^(.+?)\((\d+),(\d+)\)\s*:\s*(error|warning)\s+(\d+):\s*(.+)$/gim;

  private docIndex: Map<string, DocEntry>;

  constructor(docIndex: Map<string, DocEntry>) {
    this.docIndex = docIndex;
  }

  async diagnose(compileLog: string): Promise<string> {
    const lines = [...compileLog.matchAll(DiagnoseEngine.LOG_LINE_G)];

    if (lines.length === 0) {
      return [
        "⚠️  未在日志中找到标准格式的编译错误。",
        "",
        "支持的格式：",
        "  filename.mq5(155,39) : error 256: undeclared identifier 'ResultCode'",
        "  filename.mq5(200,15) : warning 43: possible loss of data",
        "",
        "请粘贴 MetaEditor 编译窗口的完整输出。",
      ].join("\n");
    }

    const seen = new Set<string>();
    const items: DiagnosisItem[] = [];

    for (const m of lines) {
      const [, file, line, col, severity, code, message] = m;
      const dedupeKey = `${code}::${message.trim().toLowerCase()}`;
      if (seen.has(dedupeKey)) continue;
      seen.add(dedupeKey);

      const item: DiagnosisItem = {
        location: `${file.trim()}(${line},${col})`,
        severity: severity.toLowerCase() as "error" | "warning",
        code,
        message: message.trim(),
      };

      const msgLower = message.toLowerCase();
      for (const [key, hint] of Object.entries(MIGRATION_HINTS)) {
        if (msgLower.includes(key)) {
          item.migration = `${key} → ${hint.replacement}：${hint.hint}`;
          break;
        }
      }

      if (!item.migration) {
        const identMatch = message.match(/undeclared\s+identifier\s+'?([a-z_][a-z0-9_]*)'?/i);
        if (identMatch) {
          const ident = identMatch[1].toLowerCase();
          const hint = MIGRATION_HINTS[ident];
          if (hint) {
            item.migration = `${ident} → ${hint.replacement}：${hint.hint}`;
          }
        }
      }

      const errorDb = getErrorDb();
      const dbResults = errorDb.searchError(code, message);
      if (dbResults.length > 0 && dbResults[0].solution) {
        item.dbSolution = dbResults[0].solution;
      }

      if (item.migration) {
        const identMatch = message.match(/undeclared\s+identifier\s+'?([a-z_][a-z0-9_]*)'?/i);
        const ident = identMatch ? identMatch[1].toLowerCase() : "";
        const hint = MIGRATION_HINTS[ident] || Object.values(MIGRATION_HINTS).find(h =>
          message.toLowerCase().includes(h.replacement.toLowerCase().split("/")[0].trim().toLowerCase())
        );
        if (hint) {
          for (const tk of hint.targetKeys) {
            if (this.docIndex.has(tk)) {
              item.docHint = this.docIndex.get(tk)!.relPath;
              break;
            }
          }
        }
      }

      items.push(item);
    }

    const errorCount = items.filter(i => i.severity === "error").length;
    const warnCount  = items.filter(i => i.severity === "warning").length;

    const out: string[] = [
      `🔬 编译日志诊断报告`,
      `${"=".repeat(60)}`,
      `📊 统计：${errorCount} 个错误  ${warnCount} 个警告（已去重）`,
      "",
    ];

    items.forEach((item, idx) => {
      const icon = item.severity === "error" ? "❌" : "⚠️ ";
      out.push(`${idx + 1}. ${icon} [${item.severity.toUpperCase()} ${item.code}]  ${item.location}`);
      out.push(`   消息: ${item.message}`);
      if (item.migration)  out.push(`   🔁 迁移: ${item.migration}`);
      if (item.dbSolution) out.push(`   💡 历史方案: ${item.dbSolution}`);
      if (item.docHint)    out.push(`   📄 参考文档: ${item.docHint}`);
      if (!item.migration && !item.dbSolution) {
        out.push(`   ℹ️  暂无自动诊断，建议用 smart_query("${item.message.substring(0, 40)}") 查询`);
      }
      out.push("");
    });

    out.push(`${"─".repeat(60)}`);
    out.push(`💡 提示：对未诊断的错误，可将错误消息直接传给 smart_query 获取文档支持。`);

    return out.join("\n");
  }
}
