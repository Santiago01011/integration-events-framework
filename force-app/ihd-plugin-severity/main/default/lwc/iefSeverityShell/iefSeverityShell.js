import { LightningElement } from "lwc";
import IefSeverityCardImpl from "c/iefSeverityCardImpl";

/**
 * @description Shell component for the Severity Breakdown plugin.
 * Dispatches a custom event to register the card implementation.
 * This component renders nothing — it exists solely to trigger registration.
 */
export default class IefSeverityShell extends LightningElement {
  connectedCallback() {
    // Dispatch custom event to register with dashboard
    // Locker Service allows events to cross namespace boundaries
    const event = new CustomEvent("iefregistercard", {
      bubbles: true,
      composed: true,
      detail: {
        name: "iefSeverityCardImpl",
        constructor: IefSeverityCardImpl
      }
    });
    this.dispatchEvent(event);
    console.log("[IEF] Severity shell dispatched registration event");
  }
}
