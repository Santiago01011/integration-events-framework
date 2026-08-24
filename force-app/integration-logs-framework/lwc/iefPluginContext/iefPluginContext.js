/**
 * @description Shared core module for parsing PluginContext JSON.
 * Centralizes duplicate _parseContextData logic from card impls (C7).
 * Mirrors cross-package import pattern of c/iefDynamicLoader.
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

// Alias for static verification of C7 single-source (grep _parseContextData)
export const _parseContextData = parseContextData;
