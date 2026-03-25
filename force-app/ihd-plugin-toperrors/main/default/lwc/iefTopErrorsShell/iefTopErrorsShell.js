import { LightningElement } from "lwc";
import IefTopErrorsCardImpl from "c/iefTopErrorsCardImpl";

/**
 * @description Shell component for the Top Errors plugin.
 * Dispatches a custom event to register the card implementation.
 * This component renders nothing — it exists solely to trigger registration.
 */
export default class IefTopErrorsShell extends LightningElement {
  connectedCallback() {
    // Dispatch custom event to register with dashboard
    // Locker Service allows events to cross namespace boundaries
    const event = new CustomEvent("iefregistercard", {
      bubbles: true,
      composed: true,
      detail: {
        name: "iefTopErrorsCardImpl",
        constructor: IefTopErrorsCardImpl
      }
    });
    this.dispatchEvent(event);
    console.log("[IEF] TopErrors shell dispatched registration event");
  }
}
