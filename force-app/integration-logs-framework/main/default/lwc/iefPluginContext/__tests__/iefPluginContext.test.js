import { parseContextData } from "c/iefPluginContext";

describe("c-ief-plugin-context", () => {
  describe("parseContextData", () => {
    it("returns empty filters for null input", () => {
      const result = parseContextData(null);
      expect(result.error).toBeNull();
      expect(result.context).toEqual({ filters: {} });
    });

    it("returns empty filters for empty string", () => {
      const result = parseContextData("");
      expect(result.error).toBeNull();
      expect(result.context).toEqual({ filters: {} });
    });

    it("returns empty filters for undefined", () => {
      const result = parseContextData(undefined);
      expect(result.error).toBeNull();
      expect(result.context).toEqual({ filters: {} });
    });

    it("parses valid JSON with filters", () => {
      const raw = JSON.stringify({
        pluginName: "Test",
        filters: { search: "foo", integrationCode: "BAR" },
        location: "dashboard"
      });
      const result = parseContextData(raw);
      expect(result.error).toBeNull();
      expect(result.context.pluginName).toBe("Test");
      expect(result.context.filters.search).toBe("foo");
      expect(result.context.filters.integrationCode).toBe("BAR");
    });

    it("adds empty filters when missing", () => {
      const raw = JSON.stringify({ pluginName: "Test", location: "dashboard" });
      const result = parseContextData(raw);
      expect(result.error).toBeNull();
      expect(result.context.filters).toEqual({});
      expect(result.context.pluginName).toBe("Test");
    });

    it("returns safe fallback for malformed JSON without throwing", () => {
      expect(() => parseContextData("{ malformed json")).not.toThrow();
      const result = parseContextData("{ malformed json");
      expect(result.error).toBe("Invalid context data received");
      expect(result.context).toEqual({ filters: {} });
    });

    it("returns safe fallback for invalid JSON without throwing (triangulation)", () => {
      const result = parseContextData("not json at all");
      expect(result.error).toBeTruthy();
      expect(result.context).toEqual({ filters: {} });
    });

    it("handles valid JSON with empty filters object", () => {
      const raw = JSON.stringify({ filters: {} });
      const result = parseContextData(raw);
      expect(result.error).toBeNull();
      expect(result.context.filters).toEqual({});
    });
  });
});
