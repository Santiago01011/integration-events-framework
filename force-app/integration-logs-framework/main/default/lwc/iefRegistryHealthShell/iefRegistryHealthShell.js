import { LightningElement, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import IEF_CARD_REGISTRY from "@salesforce/messageChannel/IEF_Card_Registry__c";
import { registerCard } from "c/iefDynamicLoader";
import IefRegistryHealthCard from "c/iefRegistryHealthCard";

/**
 * @description Shell component for the Registry Health reference plugin.
 * 1. Registers card implementation at module scope (deterministic)
 * 2. Publishes registration via LMS when connected (cross-component notification)
 * This component renders nothing — it exists only to trigger registration.
 */
registerCard("iefRegistryHealthCard", IefRegistryHealthCard);

export default class IefRegistryHealthShell extends LightningElement {
  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    if (this.messageContext) {
      publish(this.messageContext, IEF_CARD_REGISTRY, {
        cardName: "iefRegistryHealthCard",
        cardLabel: "Registry Health",
        action: "register"
      });
    }
  }
}
