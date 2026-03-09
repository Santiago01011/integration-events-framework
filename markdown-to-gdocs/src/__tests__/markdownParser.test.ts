import { parseMarkdown, ASTNode } from "../markdownParser";

describe("parseMarkdown", () => {
  it("parses an H1 heading", () => {
    const ast = parseMarkdown("# Hello World");
    expect(ast).toEqual<ASTNode[]>([{ type: "heading", level: 1, text: "Hello World" }]);
  });

  it("parses an H2 heading", () => {
    const ast = parseMarkdown("## Section Title");
    expect(ast).toEqual<ASTNode[]>([{ type: "heading", level: 2, text: "Section Title" }]);
  });

  it("ignores H3+ headings", () => {
    const ast = parseMarkdown("### Deep heading");
    expect(ast).toHaveLength(0);
  });

  it("parses a paragraph", () => {
    const ast = parseMarkdown("This is a paragraph.");
    expect(ast).toEqual<ASTNode[]>([{ type: "paragraph", text: "This is a paragraph." }]);
  });

  it("parses a fenced code block and strips backticks", () => {
    const ast = parseMarkdown("```typescript\nconst x = 1;\n```");
    expect(ast).toEqual<ASTNode[]>([
      { type: "code", language: "typescript", code: "const x = 1;" },
    ]);
  });

  it("parses a code block with no language", () => {
    const ast = parseMarkdown("```\nplain text\n```");
    expect(ast).toEqual<ASTNode[]>([{ type: "code", language: "", code: "plain text" }]);
  });

  it("parses a mermaid block as a mermaid node (not a code node)", () => {
    const ast = parseMarkdown("```mermaid\ngraph TD\nA --> B\n```");
    expect(ast).toEqual<ASTNode[]>([{ type: "mermaid", code: "graph TD\nA --> B" }]);
  });

  it("parses a complex multi-node markdown document", () => {
    const markdown = [
      "# Main Title",
      "",
      "## Section One",
      "",
      "A paragraph of text.",
      "",
      "```typescript",
      "const hello = 'world';",
      "```",
      "",
      "```mermaid",
      "graph TD",
      "  A --> B",
      "```",
    ].join("\n");

    const ast = parseMarkdown(markdown);

    expect(ast).toHaveLength(5);
    expect(ast[0]).toEqual<ASTNode>({ type: "heading", level: 1, text: "Main Title" });
    expect(ast[1]).toEqual<ASTNode>({ type: "heading", level: 2, text: "Section One" });
    expect(ast[2]).toEqual<ASTNode>({ type: "paragraph", text: "A paragraph of text." });
    expect(ast[3]).toEqual<ASTNode>({
      type: "code",
      language: "typescript",
      code: "const hello = 'world';",
    });
    expect(ast[4]).toEqual<ASTNode>({ type: "mermaid", code: "graph TD\n  A --> B" });
  });

  it("returns an empty array for an empty string", () => {
    expect(parseMarkdown("")).toEqual([]);
  });
});
