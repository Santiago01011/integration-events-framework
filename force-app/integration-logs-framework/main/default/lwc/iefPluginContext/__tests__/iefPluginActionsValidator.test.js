import {
  validatePluginAction,
  IEF_ACTION_TYPES
} from "../iefPluginActionsValidator";

describe("iefPluginActionsValidator", () => {
  describe("validatePluginAction", () => {
    it("rejects null or non-object messages safely", () => {
      expect(validatePluginAction(null).isValid).toBe(false);
      expect(validatePluginAction(undefined).isValid).toBe(false);
      expect(validatePluginAction("invalid").isValid).toBe(false);
      expect(validatePluginAction(123).isValid).toBe(false);
    });

    it("rejects messages with missing or non-string action", () => {
      expect(validatePluginAction({}).isValid).toBe(false);
      expect(validatePluginAction({ action: "" }).isValid).toBe(false);
      expect(validatePluginAction({ action: "   " }).isValid).toBe(false);
      expect(validatePluginAction({ action: 123 }).isValid).toBe(false);
    });

    it("rejects unsupported actions", () => {
      const result = validatePluginAction({
        action: "unknown_action",
        pluginName: "testPlugin"
      });
      expect(result.isValid).toBe(false);
      expect(result.error).toContain("Unsupported action: unknown_action");
    });

    it("validates navigate_to_filters action with all supported filter fields (including observationType for C4)", () => {
      const message = {
        action: IEF_ACTION_TYPES.NAVIGATE_TO_FILTERS,
        pluginName: "iefSeverityCardImpl",
        payload: {
          fromDate: "2026-08-20T00:00:00Z",
          toDate: "2026-08-24T23:59:59Z",
          integrationCode: "SAP_ORDERS",
          searchTerm: "ORDER_FAILED",
          observationType: "Error"
        }
      };

      const result = validatePluginAction(message);
      expect(result.isValid).toBe(true);
      expect(result.action).toBe(IEF_ACTION_TYPES.NAVIGATE_TO_FILTERS);
      expect(result.pluginName).toBe("iefSeverityCardImpl");
      expect(result.payload.fromDate).toBe("2026-08-20T00:00:00Z");
      expect(result.payload.toDate).toBe("2026-08-24T23:59:59Z");
      expect(result.payload.integrationCode).toBe("SAP_ORDERS");
      expect(result.payload.searchTerm).toBe("ORDER_FAILED");
      expect(result.payload.observationType).toBe("Error");
    });

    it("sanitizes navigate_to_filters payload omitting unknown or invalid properties", () => {
      const message = {
        action: "navigate_to_filters",
        pluginName: "customPlugin",
        payload: {
          integrationCode: "  SALESFORCE_PAYMENTS  ",
          observationType: " Warning ",
          unsupportedField: 12345
        }
      };

      const result = validatePluginAction(message);
      expect(result.isValid).toBe(true);
      expect(result.payload.integrationCode).toBe("SALESFORCE_PAYMENTS");
      expect(result.payload.observationType).toBe("Warning");
      expect(result.payload.unsupportedField).toBeUndefined();
    });

    it("validates refresh_dashboard action with default and custom reasons", () => {
      const resultDefault = validatePluginAction({
        action: IEF_ACTION_TYPES.REFRESH_DASHBOARD,
        pluginName: "iefRefreshButton"
      });
      expect(resultDefault.isValid).toBe(true);
      expect(resultDefault.payload.reason).toBe("plugin_request");

      const resultCustom = validatePluginAction({
        action: IEF_ACTION_TYPES.REFRESH_DASHBOARD,
        pluginName: "iefRefreshButton",
        payload: { reason: "manual_user_click" }
      });
      expect(resultCustom.isValid).toBe(true);
      expect(resultCustom.payload.reason).toBe("manual_user_click");
    });
  });
});
