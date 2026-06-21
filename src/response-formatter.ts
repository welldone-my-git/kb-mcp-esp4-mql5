import type { QueryAnalysis } from "./query-analyzer.js";
import type { ExtractedInfo } from "./info-extractor.js";

export interface SmartQueryResult {
  type: "quick" | "detailed";
  answer: string;
  code?: string;
  syntax?: string;
  parameters?: string;
  returns?: string;
  example?: string;
  notes?: string[];
  reference: string;
  relatedDocs?: string[];
  estimatedTokens: number;
}

export class ResponseFormatter {
  static formatQuick(
    extracted: ExtractedInfo,
    analysis: QueryAnalysis,
    docName: string
  ): SmartQueryResult {
    let answer = "";

    if (analysis.type === "error") {
      answer = `❌ 错误诊断\n\n`;
      if (extracted.description) {
        answer += `${extracted.description.substring(0, 150)}\n`;
      }
      answer += `\n💡 解决方案：\n`;
      if (extracted.syntax) {
        answer += `使用: ${extracted.syntax}\n`;
      }
    } else if (analysis.type === "function" || analysis.type === "class") {
      answer = extracted.syntax || extracted.description?.substring(0, 100) || "函数/类说明";
    } else {
      answer = extracted.description?.substring(0, 200) || "查询结果";
    }

    return {
      type: "quick",
      answer,
      code: extracted.example?.substring(0, 200),
      reference: docName,
      estimatedTokens: 500,
    };
  }

  static formatDetailed(
    extracted: ExtractedInfo,
    analysis: QueryAnalysis,
    docName: string,
    relatedDocs: string[]
  ): SmartQueryResult {
    return {
      type: "detailed",
      answer: extracted.description || "详细说明",
      syntax: extracted.syntax,
      parameters: extracted.parameters,
      returns: extracted.returns,
      example: extracted.example,
      notes: extracted.notes,
      reference: docName,
      relatedDocs: relatedDocs.slice(0, 3),
      estimatedTokens: 1500,
    };
  }
}
