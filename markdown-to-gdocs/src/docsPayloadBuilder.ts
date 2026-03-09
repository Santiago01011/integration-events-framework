import { ASTNode } from "./markdownParser";

export type GoogleDocsRequest = Record<string, unknown>;

const PLACEHOLDER = "{{CONTENT}}";
const MONOSPACE_FONT = "Courier New";

/**
 * Translates an AST (produced by `parseMarkdown`) into an array of Google Docs
 * `batchUpdate` request objects.
 *
 * Anchor logic:
 *  1. A `deleteContentRange` request removes the `{{CONTENT}}` placeholder at
 *     `placeholderIndex`.
 *  2. Each AST node produces an `insertText` request followed by the appropriate
 *     style request (`updateParagraphStyle` or `updateTextStyle`).
 *
 * Style mapping:
 *  - H1  → `HEADING_1` paragraph style
 *  - H2  → `HEADING_2` paragraph style
 *  - Code / Mermaid → Courier New monospaced text style
 *  - Paragraph → `NORMAL_TEXT` paragraph style
 *
 * @param ast             - AST produced by `parseMarkdown`.
 * @param placeholderIndex - Character index of `{{CONTENT}}` in the target document
 *                          (obtained from a prior Google Docs API lookup).
 * @returns Array of Google Docs `batchUpdate` request objects.
 *
 * @example
 * const requests = buildDocsPayload(ast, 42);
 * // Pass `requests` as the body of a `documents.batchUpdate` call.
 */
export function buildDocsPayload(
  ast: ASTNode[],
  placeholderIndex: number,
): GoogleDocsRequest[] {
  const requests: GoogleDocsRequest[] = [];

  requests.push({
    deleteContentRange: {
      range: {
        startIndex: placeholderIndex,
        endIndex: placeholderIndex + PLACEHOLDER.length,
      },
    },
  });

  let currentIndex = placeholderIndex;

  for (const node of ast) {
    const text = getNodeText(node) + "\n";
    const startIndex = currentIndex;
    const endIndex = startIndex + text.length;

    requests.push({
      insertText: {
        location: { index: startIndex },
        text,
      },
    });

    requests.push(buildStyleRequest(node, startIndex, endIndex));

    currentIndex = endIndex;
  }

  return requests;
}

function getNodeText(node: ASTNode): string {
  switch (node.type) {
    case "heading":
      return node.text;
    case "paragraph":
      return node.text;
    case "code":
      return node.code;
    case "mermaid":
      return node.code;
  }
}

function buildStyleRequest(
  node: ASTNode,
  startIndex: number,
  endIndex: number,
): GoogleDocsRequest {
  switch (node.type) {
    case "heading":
      return {
        updateParagraphStyle: {
          range: { startIndex, endIndex },
          paragraphStyle: {
            namedStyleType: node.level === 1 ? "HEADING_1" : "HEADING_2",
          },
          fields: "namedStyleType",
        },
      };

    case "paragraph":
      return {
        updateParagraphStyle: {
          range: { startIndex, endIndex },
          paragraphStyle: { namedStyleType: "NORMAL_TEXT" },
          fields: "namedStyleType",
        },
      };

    case "code":
    case "mermaid":
      return {
        updateTextStyle: {
          range: { startIndex, endIndex: endIndex - 1 },
          textStyle: {
            weightedFontFamily: { fontFamily: MONOSPACE_FONT },
          },
          fields: "weightedFontFamily",
        },
      };
  }
}
