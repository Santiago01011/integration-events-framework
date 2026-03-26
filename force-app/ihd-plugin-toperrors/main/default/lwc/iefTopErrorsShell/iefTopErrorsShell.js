import { LightningElement } from "lwc";
import { registerCard } from "c/iefDynamicLoader";
import IefTopErrorsCardImpl from "c/iefTopErrorsCardImpl";

/**
 * @description Shell component for the Top Errors plugin.
 * Registers card implementation at module scope (deterministic).
 * This component renders nothing — it exists only to trigger registration.
 */
registerCard("iefTopErrorsCardImpl", IefTopErrorsCardImpl);

export default class IefTopErrorsShell extends LightningElement {}
