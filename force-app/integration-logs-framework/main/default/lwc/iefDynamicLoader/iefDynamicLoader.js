/**
 * @description Single registry for plugin card constructors.
 * This is a pure JS module — no LightningElement, no HTML template.
 *
 * Plugins register at module scope via registerCard():
 *   import { registerCard } from "c/iefDynamicLoader";
 *   registerCard("iefTopErrorsCardImpl", IefTopErrorsCardImpl);
 *
 * Dashboard resolves constructors via getConstructor():
 *   import { getConstructor } from "c/iefDynamicLoader";
 *   const ctor = getConstructor("iefTopErrorsCardImpl");
 *
 * Module-scope registration is deterministic — executes on import,
 * before any connectedCallback, with no race conditions.
 */

/** @type {Map<string, Function>} The single registry */
const registry = new Map();

/**
 * Registers a card constructor in the registry.
 * Call at module scope (outside class) for deterministic registration.
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

/**
 * Clears all registrations. For testing only.
 * In production, registrations persist for the page lifetime.
 */
export function clearRegistry() {
  registry.clear();
}
