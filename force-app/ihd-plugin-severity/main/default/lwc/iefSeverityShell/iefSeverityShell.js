import { LightningElement, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import IEF_CARD_REGISTRY from "@salesforce/messageChannel/IEF_Card_Registry__c";
import { registerCard } from "c/iefDynamicLoader";
import IefSeverityCardImpl from "c/iefSeverityCardImpl";

/**
 * @description Shell component for the Severity Breakdown plugin.
 * 1. Registers card implementation at module scope (deterministic)
 * 2. Publishes registration via LMS when connected (cross-component notification)
 * This component renders nothing — it exists only to trigger registration.
 */
registerCard("iefSeverityCardImpl", IefSeverityCardImpl);

export default class IefSeverityShell extends LightningElement {
  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    // Notify dashboard that this card is registered
    if (this.messageContext) {
      publish(this.messageContext, IEF_CARD_REGISTRY, {
        cardName: "iefSeverityCardImpl",
        cardLabel: "Severity Breakdown",
        action: "register"
      });
    }
  }
}
