import { LightningElement, api } from "lwc";

/**
 * @description Placeholder shown when a plugin shell is not placed on the page
 * or when a plugin constructor has not been registered in the dynamic loader.
 */
export default class IefCardPlaceholder extends LightningElement {
  /** @type {string} Label to display for the plugin */
  @api pluginLabel = "";

  /** @type {string} Technical name of the plugin */
  @api pluginName = "";

  /** @type {string} Human-readable reason when card cannot render */
  @api pluginReason = "";

  get displayLabel() {
    return this.pluginLabel && this.pluginLabel.trim() !== ""
      ? this.pluginLabel
      : this.pluginName;
  }

  /**
   * @description Subtitle text explaining how to activate the card.
   * @returns {string}
   */
  get subtitle() {
    if (this.pluginReason && this.pluginReason.trim() !== "") {
      return this.pluginReason;
    }
    return "Add the plugin shell component to this page to activate this card";
  }
}
