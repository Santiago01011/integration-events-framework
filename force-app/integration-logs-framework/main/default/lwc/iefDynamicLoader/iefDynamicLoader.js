/**
 * @description Dynamic loader module that maintains a registry of LWC constructors.
 * This is a pure JS module — no LightningElement, no HTML template.
 * Core SHALL NOT static import any plugin LWC; plugins register themselves
 * at module scope via registerCard().
 *
 * Uses window.__iefCardRegistry for cross-package registration since
 * c/ prefix only works within the same package.
 */

// Initialize global registry for cross-package communication
if (typeof window !== "undefined" && !window.__iefCardRegistry) {
  window.__iefCardRegistry = new Map();
}

const registry =
  typeof window !== "undefined" ? window.__iefCardRegistry : new Map();

/**
 * Registers a card constructor in the registry.
 * @param {string} name - Component name (must be non-empty string)
 * @param {Function} constructor - LWC constructor (must be non-null)
 */
export function registerCard(name, constructor) {
  if (typeof name !== "string" || name.trim() === "") {
    return;
  }
  if (constructor === null || constructor === undefined) {
    return;
  }
  if (registry.has(name)) {
    console.warn(`[iefDynamicLoader] Duplicate registration for "${name}"`);
    return;
  }
  registry.set(name, constructor);
  console.log(`[iefDynamicLoader] Registered: "${name}"`);
}

/**
 * Retrieves a registered constructor by name.
 * @param {string} name - Component name
 * @returns {Function|null} The constructor or null if not found
 */
export function getConstructor(name) {
  return registry.get(name) ?? null;
}

/**
 * Returns all registered component names.
 * @returns {string[]} Array of registered names
 */
export function getRegisteredNames() {
  return Array.from(registry.keys());
}
