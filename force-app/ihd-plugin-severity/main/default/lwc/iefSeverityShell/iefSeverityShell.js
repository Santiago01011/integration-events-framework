import { LightningElement } from "lwc";
import { registerCard } from "c/iefDynamicLoader";
import IefSeverityCardImpl from "c/iefSeverityCardImpl";

/**
 * @description Shell component for the Severity Breakdown plugin.
 * Registers the card implementation with the dynamic loader at module scope.
 * This component renders nothing — it exists solely to trigger registration
 * when placed on a Lightning page.
 */
registerCard("iefSeverityCardImpl", IefSeverityCardImpl);

export default class IefSeverityShell extends LightningElement {}
