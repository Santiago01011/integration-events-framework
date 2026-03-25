import { LightningElement } from "lwc";
import IefTopErrorsCardImpl from "c/iefTopErrorsCardImpl";

/**
 * @description Shell component for the Top Errors plugin.
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
  window.__iefCardRegistry.set("iefTopErrorsCardImpl", IefTopErrorsCardImpl);
  console.log("[IEF] TopErrors shell registered");
}

export default class IefTopErrorsShell extends LightningElement {}
