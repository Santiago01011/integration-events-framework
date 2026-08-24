import {
  IEF_ACTION_TYPES,
  validatePluginAction
} from "./iefPluginActionsValidator";

/**
 * @description Shared core module for parsing PluginContext JSON and validating LMS actions.
 *
 * @param {string} raw - Raw contextData JSON string from dashboard
 * @returns {{context: Object, error: string|null}} Parsed context and error (null when valid)
 */
export function parseContextData(raw) {
  if (!raw || raw === "") {
    return { context: { filters: {} }, error: null };
  }
  try {
    const parsed = JSON.parse(raw);
    if (!parsed.filters) {
      parsed.filters = {};
    }
    return { context: parsed, error: null };
  } catch {
    return { context: { filters: {} }, error: "Invalid context data received" };
  }
}

export const _parseContextData = parseContextData;
export { IEF_ACTION_TYPES, validatePluginAction };
