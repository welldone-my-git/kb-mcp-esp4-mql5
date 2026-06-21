export interface QueryAnalysis {
  type: "error" | "function" | "class" | "migration" | "howto" | "concept";
  keywords: string[];
  context?: string;
  originalQuery: string;
}

export class QueryAnalyzer {
  private static ERROR_PATTERNS = [
    /error[:\s]+([A-Z]\d+)[:\s]+([^'"]+)/i,
    /\b([A-Z]\d{3,4})\b[:\s]+([^'"]+)/i,
    /undeclared\s+identifier\s+'?([a-z_][a-z0-9_]*)'?/i,
    /'([a-z_][a-z0-9_]*)'\s*-\s*undeclared/i,
  ];

  static extractErrorCode(query: string): string | null {
    const match = query.match(/\b([A-Z]\d{3,4})\b/);
    return match ? match[1] : null;
  }

  private static FUNCTION_PATTERNS = [
    /^([A-Z][a-zA-Z0-9_]+)(?:\(\))?$/,
    /how\s+to\s+use\s+([A-Z][a-zA-Z0-9_]+)/i,
  ];

  private static CLASS_PATTERNS = [
    /^C?([A-Z][a-zA-Z0-9_]+)\s+class/i,
    /^C([A-Z][a-zA-Z0-9_]+)$/,
  ];

  private static HOWTO_PATTERNS = [
    /(?:how|如何|怎么|怎样)\s+(?:to|do|实现|做|用)/i,
    /(?:what|什么)\s+(?:is|are)/i,
  ];

  static analyze(query: string): QueryAnalysis {
    const queryLower = query.toLowerCase().trim();

    for (const pattern of this.ERROR_PATTERNS) {
      const match = query.match(pattern);
      if (match) {
        const identifier = match[1] || match[2];
        return {
          type: "error",
          keywords: [identifier.toLowerCase()],
          context: "error_diagnosis",
          originalQuery: query,
        };
      }
    }

    for (const pattern of this.FUNCTION_PATTERNS) {
      const match = query.match(pattern);
      if (match) {
        return {
          type: "function",
          keywords: [match[1].toLowerCase()],
          originalQuery: query,
        };
      }
    }

    for (const pattern of this.CLASS_PATTERNS) {
      const match = query.match(pattern);
      if (match) {
        return {
          type: "class",
          keywords: [match[1].toLowerCase(), `c${match[1].toLowerCase()}`],
          originalQuery: query,
        };
      }
    }

    for (const pattern of this.HOWTO_PATTERNS) {
      if (pattern.test(query)) {
        return {
          type: "howto",
          keywords: this.extractKeywords(query),
          originalQuery: query,
        };
      }
    }

    return {
      type: "concept",
      keywords: this.extractKeywords(query),
      originalQuery: query,
    };
  }

  private static extractKeywords(query: string): string[] {
    const stopWords = new Set([
      "how", "to", "use", "the", "a", "an", "is", "are", "in", "on", "at",
      "如何", "怎么", "使用", "的", "了", "吗", "呢",
    ]);

    return query
      .toLowerCase()
      .replace(/[^\w\s]/g, " ")
      .split(/\s+/)
      .filter((word) => word.length > 2 && !stopWords.has(word));
  }
}
