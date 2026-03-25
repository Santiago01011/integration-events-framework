import { LightningElement } from "lwc";
import { registerCard } from "c/iefDynamicLoader";
import IefTopErrorsCardImpl from "c/iefTopErrorsCardImpl";

/**
 * @description Shell component for the Top Errors plugin.
 * Registers the card implementation with the dynamic loader at module scope.
 * This component renders nothing — it exists solely to trigger registration
 * when placed on a Lightning page.
 */
registerCard("iefTopErrorsCardImpl", IefTopErrorsCardImpl);

export default class IefTopErrorsShell extends LightningElement {}
