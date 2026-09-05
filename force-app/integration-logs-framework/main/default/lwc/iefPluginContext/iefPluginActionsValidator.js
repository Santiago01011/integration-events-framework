/**
 * @description Action types supported across the framework via LMS.
 */
export const IEF_ACTION_TYPES = Object.freeze({
  NAVIGATE_TO_FILTERS: "navigate_to_filters",
  REFRESH_DASHBOARD: "refresh_dashboard"
});

/**
 * Validates and sanitizes LMS action messages received from plugins.
 * Ensures malformed, oversized, or unauthorized payloads do not corrupt dashboard state.
 *
 * @param {Object} message - Raw LMS message
 * @returns {{
 *   isValid: boolean,
 *   action?: string,
 *   pluginName?: string,
 *   payload: Object,
 *   error?: string
 * }}
 */
export function validatePluginAction(message) {
  if (!message || typeof message !== "object") {
    return { isValid: false, payload: {}, error: "Message must be an object" };
  }

  const { action, pluginName, payload } = message;

  if (typeof action !== "string" || action.trim() === "") {
    return {
      isValid: false,
      payload: {},
      error: "Action is required and must be a non-empty string"
    };
  }

  const cleanAction = action.trim();
  const cleanPlugin =
    typeof pluginName === "string" && pluginName.trim() !== ""
      ? pluginName.trim()
      : "unknown";
  const rawPayload = payload && typeof payload === "object" ? payload : {};

  switch (cleanAction) {
    case IEF_ACTION_TYPES.NAVIGATE_TO_FILTERS: {
      const sanitized = {};
      if (rawPayload.fromDate && typeof rawPayload.fromDate === "string") {
        sanitized.fromDate = rawPayload.fromDate;
      }
      if (rawPayload.toDate && typeof rawPayload.toDate === "string") {
        sanitized.toDate = rawPayload.toDate;
      }
      if (
        rawPayload.integrationCode &&
        typeof rawPayload.integrationCode === "string"
      ) {
        sanitized.integrationCode = rawPayload.integrationCode.trim();
      }
      if (rawPayload.searchTerm && typeof rawPayload.searchTerm === "string") {
        sanitized.searchTerm = rawPayload.searchTerm.trim();
      }
      if (
        rawPayload.observationType &&
        typeof rawPayload.observationType === "string"
      ) {
        sanitized.observationType = rawPayload.observationType.trim();
      }

      return {
        isValid: true,
        action: cleanAction,
        pluginName: cleanPlugin,
        payload: sanitized
      };
    }

    case IEF_ACTION_TYPES.REFRESH_DASHBOARD: {
      return {
        isValid: true,
        action: cleanAction,
        pluginName: cleanPlugin,
        payload: {
          reason:
            typeof rawPayload.reason === "string" &&
            rawPayload.reason.trim() !== ""
              ? rawPayload.reason.trim()
              : "plugin_request"
        }
      };
    }

    default:
      return {
        isValid: false,
        action: cleanAction,
        pluginName: cleanPlugin,
        payload: {},
        error: `Unsupported action: ${cleanAction}`
      };
  }
}
