import { LightningElement } from "lwc";
import IefSeverityCardImpl from "c/iefSeverityCardImpl";

/**
 * @description Shell component for the Severity Breakdown plugin.
 * Registers the card implementation with the global registry at module scope.
 * This component renders nothing — it exists solely to trigger registration
 * when placed on a Lightning page.
 *
 * Uses window.__iefCardRegistry for cross-package communication since
 * c/ prefix only works within the same package.
 */
if (typeof window !== "undefined") {
  if (!window.__iefCardRegistry) {
    window.__iefCardRegistry = new Map();
  }
  window.__iefCardRegistry.set("iefSeverityCardImpl", IefSeverityCardImpl);
  console.log("[IEF] Severity shell registered");
}

export default class IefSeverityShell extends LightningElement {}
