import {
  registerCard,
  getConstructor,
  getRegisteredNames
} from "c/iefDynamicLoader";

describe("c-ief-dynamic-loader", () => {
  // Each test gets a fresh registry since Map is module-level
  // We clear by getting all names and noting the registry persists across tests
  // The tests are ordered to verify the full lifecycle

  describe("registerCard", () => {
    it("registers a valid card constructor", () => {
      const mockCtor = function MockCard() {};
      registerCard("TestCard1", mockCtor);

      expect(getConstructor("TestCard1")).toBe(mockCtor);
    });

    it("does not throw when registering with empty string name", () => {
      expect(() => {
        registerCard("", function () {});
      }).not.toThrow();
      expect(() => {
        registerCard("   ", function () {});
      }).not.toThrow();
    });

    it("does not throw when registering with null constructor", () => {
      expect(() => {
        registerCard("NullTestCard", null);
      }).not.toThrow();
      expect(() => {
        registerCard("UndefinedTestCard", undefined);
      }).not.toThrow();
    });

    it("does not throw on duplicate registration and logs warning", () => {
      const mockCtor = function DupCard() {};
      const warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {});

      registerCard("DupCard", mockCtor);
      // Register again with same name
      expect(() => {
        registerCard("DupCard", function OtherCard() {});
      }).not.toThrow();

      expect(warnSpy).toHaveBeenCalledWith(
        expect.stringContaining('Duplicate registration for "DupCard"')
      );

      // Original constructor should still be there
      expect(getConstructor("DupCard")).toBe(mockCtor);

      warnSpy.mockRestore();
    });
  });

  describe("getConstructor", () => {
    it("returns null for unregistered component name", () => {
      expect(getConstructor("NonExistentCard")).toBeNull();
    });
  });

  describe("getRegisteredNames", () => {
    it("returns an array of all registered names", () => {
      const names = getRegisteredNames();
      expect(Array.isArray(names)).toBe(true);
      // Verify our test registrations are present
      expect(names).toContain("TestCard1");
      expect(names).toContain("DupCard");
    });
  });
});
