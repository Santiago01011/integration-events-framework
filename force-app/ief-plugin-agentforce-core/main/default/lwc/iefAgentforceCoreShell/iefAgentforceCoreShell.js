import { LightningElement, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import IEF_CARD_REGISTRY from "@salesforce/messageChannel/IEF_Card_Registry__c";
import { registerCard } from "c/iefDynamicLoader";
import IefAgentforceCoreCardImpl from "c/iefAgentforceCoreCardImpl";

registerCard("iefAgentforceCoreCardImpl", IefAgentforceCoreCardImpl);

export default class IefAgentforceCoreShell extends LightningElement {
  @wire(MessageContext)
  messageContext;

  _registrationPending = true;

  /**
   * @description Wire is not guaranteed to resolve before connectedCallback fires.
   * We defer the registration publish to renderedCallback, where the wire adapter
   * will always be ready. A one-shot flag prevents duplicate publishes.
   */
  renderedCallback() {
    if (this._registrationPending && this.messageContext) {
      this._registrationPending = false;
      publish(this.messageContext, IEF_CARD_REGISTRY, {
        cardName: "iefAgentforceCoreCardImpl",
        cardLabel: "Agentforce Core Pulse",
        action: "register"
      });
    }
  }
}
