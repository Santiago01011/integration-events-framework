import { marked } from "marked";

export type HeadingNode = {
  type: "heading";
  level: 1 | 2;
  text: string;
};

export type ParagraphNode = {
  type: "paragraph";
  text: string;
};

export type CodeBlockNode = {
  type: "code";
  language: string;
  code: string;
};

export type MermaidNode = {
  type: "mermaid";
  code: string;
};

export type ASTNode = HeadingNode | ParagraphNode | CodeBlockNode | MermaidNode;

/**
 * Parses a Markdown string into a structured AST array.
 *
 * Supports:
 *  - H1 and H2 headings
 *  - Paragraphs
 *  - Fenced code blocks (language extracted, backticks stripped)
 *  - Mermaid diagram blocks (identified separately for future image processing)
 *
 * @param markdown - Raw markdown string to parse.
 * @returns Array of ASTNode representing the document structure.
 *
 * @example
 * const ast = parseMarkdown('# Title\n\nA paragraph.');
 * // [{ type: 'heading', level: 1, text: 'Title' }, { type: 'paragraph', text: 'A paragraph.' }]
 */
export function parseMarkdown(markdown: string): ASTNode[] {
  const tokens = marked.lexer(markdown);
  const nodes: ASTNode[] = [];

  for (const token of tokens) {
    switch (token.type) {
      case "heading":
        if (token.depth === 1 || token.depth === 2) {
          nodes.push({ type: "heading", level: token.depth, text: token.text });
        }
        break;

      case "paragraph":
        nodes.push({ type: "paragraph", text: token.text });
        break;

      case "code":
        if (token.lang === "mermaid") {
          nodes.push({ type: "mermaid", code: token.text });
        } else {
          nodes.push({ type: "code", language: token.lang ?? "", code: token.text });
        }
        break;

      default:
        break;
    }
  }

  return nodes;
}
