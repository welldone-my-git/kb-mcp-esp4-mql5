import type { DocEntry } from "./core/plugin.js";
import { getErrorDb } from "./error-db.js";
import { QueryAnalyzer } from "./query-analyzer.js";
import { InfoExtractor } from "./info-extractor.js";
import { ResponseFormatter } from "./response-formatter.js";
import type { SmartQueryResult } from "./response-formatter.js";

export type { SmartQueryResult };

export class SmartQueryEngine {
  private docIndex: Map<string, DocEntry>;

  constructor(docIndex: Map<string, DocEntry>) {
    this.docIndex = docIndex;
  }

  private internalSearch(keywords: string[], limit: number = 3): DocEntry[] {
    const results: Array<{ entry: DocEntry; score: number }> = [];

    for (const [key, entry] of this.docIndex.entries()) {
      let score = 0;

      for (const keyword of keywords) {
        if (key === keyword) {
          score += 100;
        } else if (key.includes(keyword)) {
          score += 50;
        } else if (keyword.includes(key)) {
          score += 25;
        }
      }

      if (score > 0) {
        results.push({ entry, score });
      }
    }

    results.sort((a, b) => b.score - a.score);
    return results.slice(0, limit).map((r) => r.entry);
  }

  private searchErrorDatabase(query: string, errorCode: string | null) {
    const errorDb = getErrorDb();

    if (errorCode) {
      return errorDb.searchError(errorCode);
    } else {
      return errorDb.searchSimilarErrors(query);
    }
  }

  async query(query: string, mode: "quick" | "detailed" = "quick"): Promise<SmartQueryResult> {
    const analysis = QueryAnalyzer.analyze(query);

    if (analysis.type === "error") {
      const errorCode = QueryAnalyzer.extractErrorCode(query);
      const dbResults = this.searchErrorDatabase(query, errorCode);

      if (dbResults.length > 0) {
        const topError = dbResults[0];
        let relatedDocs: string[] = [];
        if (topError.related_docs) {
          try {
            const parsed = JSON.parse(topError.related_docs);
            if (Array.isArray(parsed)) {
              relatedDocs = parsed.filter((item): item is string => typeof item === "string");
            } else if (typeof parsed === "string") {
              relatedDocs = [parsed];
            }
          } catch (e) {
            console.warn(`[smart-query] failed to parse related_docs: ${e}`);
            relatedDocs = [];
          }
        }
        const answer = `🔍 **从错误数据库找到解决方案** (出现${topError.occurrence_count}次)\n\n` +
          `**错误:** ${topError.error_code} - ${topError.error_message}\n\n` +
          (topError.solution ? `**解决方案:**\n${topError.solution}\n\n` : '') +
          (topError.related_docs ? `**相关文档:**\n${topError.related_docs}\n\n` : '') +
          `💡 提示: 如果此解决方案无效,请使用 smart_query 从文档中查询更多信息`;

        return {
          type: mode,
          answer,
          reference: "错误数据库",
          relatedDocs,
          estimatedTokens: Math.ceil(answer.length / 4),
        };
      }
    }

    const candidates = this.internalSearch(analysis.keywords, mode === "quick" ? 1 : 3);

    if (candidates.length === 0) {
      return {
        type: mode,
        answer: `❌ 未找到相关文档，关键词: ${analysis.keywords.join(", ")}`,
        reference: "无",
        estimatedTokens: 100,
      };
    }

    const primaryDoc = candidates[0];
    const extracted = await InfoExtractor.extract(primaryDoc.absPath);

    if (mode === "quick") {
      return ResponseFormatter.formatQuick(extracted, analysis, primaryDoc.relPath);
    } else {
      const relatedDocs = candidates.slice(1).map((c) => c.relPath);
      return ResponseFormatter.formatDetailed(extracted, analysis, primaryDoc.relPath, relatedDocs);
    }
  }
}
