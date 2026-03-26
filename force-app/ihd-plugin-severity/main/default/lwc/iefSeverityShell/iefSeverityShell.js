import { LightningElement } from "lwc";
import { registerCard } from "c/iefDynamicLoader";
import IefSeverityCardImpl from "c/iefSeverityCardImpl";

/**
 * @description Shell component for the Severity Breakdown plugin.
 * Registers card implementation at module scope (deterministic).
 * This component renders nothing — it exists only to trigger registration.
 */
registerCard("iefSeverityCardImpl", IefSeverityCardImpl);

export default class IefSeverityShell extends LightningElement {}
