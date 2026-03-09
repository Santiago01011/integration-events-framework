import { buildDocsPayload, GoogleDocsRequest } from "../docsPayloadBuilder";
import { ASTNode } from "../markdownParser";

const PLACEHOLDER_INDEX = 100;
const PLACEHOLDER_LENGTH = "{{CONTENT}}".length;

describe("buildDocsPayload", () => {
  it("always starts with a deleteContentRange for the {{CONTENT}} placeholder", () => {
    const requests = buildDocsPayload([], PLACEHOLDER_INDEX);

    expect(requests[0]).toEqual<GoogleDocsRequest>({
      deleteContentRange: {
        range: {
          startIndex: PLACEHOLDER_INDEX,
          endIndex: PLACEHOLDER_INDEX + PLACEHOLDER_LENGTH,
        },
      },
    });
  });

  it("returns only the delete request when the AST is empty", () => {
    const requests = buildDocsPayload([], PLACEHOLDER_INDEX);
    expect(requests).toHaveLength(1);
  });

  it("generates insertText + updateParagraphStyle(HEADING_1) for an H1 node", () => {
    const ast: ASTNode[] = [{ type: "heading", level: 1, text: "Hello World" }];
    const requests = buildDocsPayload(ast, PLACEHOLDER_INDEX);

    expect(requests[1]).toEqual<GoogleDocsRequest>({
      insertText: {
        location: { index: PLACEHOLDER_INDEX },
        text: "Hello World\n",
      },
    });

    expect(requests[2]).toEqual<GoogleDocsRequest>({
      updateParagraphStyle: {
        range: {
          startIndex: PLACEHOLDER_INDEX,
          endIndex: PLACEHOLDER_INDEX + "Hello World\n".length,
        },
        paragraphStyle: { namedStyleType: "HEADING_1" },
        fields: "namedStyleType",
      },
    });
  });

  it("generates updateParagraphStyle(HEADING_2) for an H2 node", () => {
    const ast: ASTNode[] = [{ type: "heading", level: 2, text: "Section" }];
    const requests = buildDocsPayload(ast, PLACEHOLDER_INDEX);

    expect(requests[2]).toMatchObject({
      updateParagraphStyle: {
        paragraphStyle: { namedStyleType: "HEADING_2" },
      },
    });
  });

  it("generates insertText + updateParagraphStyle(NORMAL_TEXT) for a paragraph node", () => {
    const ast: ASTNode[] = [{ type: "paragraph", text: "Some text." }];
    const requests = buildDocsPayload(ast, PLACEHOLDER_INDEX);

    expect(requests[1]).toEqual<GoogleDocsRequest>({
      insertText: {
        location: { index: PLACEHOLDER_INDEX },
        text: "Some text.\n",
      },
    });

    expect(requests[2]).toMatchObject({
      updateParagraphStyle: {
        paragraphStyle: { namedStyleType: "NORMAL_TEXT" },
      },
    });
  });

  it("generates insertText + updateTextStyle(Courier New) for a code node", () => {
    const code = "const x = 1;";
    const ast: ASTNode[] = [{ type: "code", language: "js", code }];
    const requests = buildDocsPayload(ast, PLACEHOLDER_INDEX);

    expect(requests[1]).toEqual<GoogleDocsRequest>({
      insertText: {
        location: { index: PLACEHOLDER_INDEX },
        text: `${code}\n`,
      },
    });

    expect(requests[2]).toMatchObject({
      updateTextStyle: {
        textStyle: {
          weightedFontFamily: { fontFamily: "Courier New" },
        },
        fields: "weightedFontFamily",
      },
    });
  });

  it("generates insertText + updateTextStyle(Courier New) for a mermaid node", () => {
    const ast: ASTNode[] = [{ type: "mermaid", code: "graph TD\nA --> B" }];
    const requests = buildDocsPayload(ast, PLACEHOLDER_INDEX);

    expect(requests[2]).toMatchObject({
      updateTextStyle: {
        textStyle: {
          weightedFontFamily: { fontFamily: "Courier New" },
        },
      },
    });
  });

  it("excludes the trailing newline from the text style range for code/mermaid", () => {
    const code = "hello";
    const ast: ASTNode[] = [{ type: "code", language: "", code }];
    const requests = buildDocsPayload(ast, PLACEHOLDER_INDEX);
    const styleReq = requests[2] as { updateTextStyle: { range: { endIndex: number } } };

    expect(styleReq.updateTextStyle.range.endIndex).toBe(
      PLACEHOLDER_INDEX + code.length,
    );
  });

  it("correctly tracks insertion indices across multiple nodes", () => {
    const ast: ASTNode[] = [
      { type: "heading", level: 1, text: "Title" },
      { type: "paragraph", text: "Body." },
    ];
    const requests = buildDocsPayload(ast, PLACEHOLDER_INDEX);

    const titleText = "Title\n";
    const bodyInsert = requests.find(
      (r) =>
        "insertText" in r &&
        (r.insertText as { text: string }).text === "Body.\n",
    );

    expect(bodyInsert).toEqual<GoogleDocsRequest>({
      insertText: {
        location: { index: PLACEHOLDER_INDEX + titleText.length },
        text: "Body.\n",
      },
    });
  });

  it("produces 2 requests per AST node plus 1 delete request", () => {
    const ast: ASTNode[] = [
      { type: "heading", level: 1, text: "A" },
      { type: "paragraph", text: "B" },
      { type: "code", language: "ts", code: "C" },
    ];
    const requests = buildDocsPayload(ast, PLACEHOLDER_INDEX);
    expect(requests).toHaveLength(1 + ast.length * 2);
  });
});
