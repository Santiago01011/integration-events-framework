import { LightningElement, api } from "lwc";

/**
 * @description Card implementation for the Top Errors plugin.
 * Receives context data as a JSON string from the dashboard host.
 * This component is dynamically rendered via lwc:is — never static-imported by core.
 */
export default class IefTopErrorsCardImpl extends LightningElement {
  /** @type {string} JSON string with plugin context data */
  @api contextData = "";

  /** @type {Object} Parsed context object */
  parsedContext = null;

  /** @type {boolean} Whether data is loading */
  isLoading = true;

  /** @type {boolean} Whether an error occurred */
  hasError = false;

  /** @type {string} Error message */
  errorMessage = "";

  connectedCallback() {
    this._parseContextData();
  }

  /**
   * @description Parses the contextData JSON string safely.
   * @private
   */
  _parseContextData() {
    this.isLoading = true;
    this.hasError = false;
    this.errorMessage = "";

    if (!this.contextData || this.contextData === "") {
      this.parsedContext = {};
      this.isLoading = false;
      return;
    }

    try {
      this.parsedContext = JSON.parse(this.contextData);
    } catch {
      this.hasError = true;
      this.errorMessage = "Invalid context data received";
      this.parsedContext = null;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Re-parses when contextData changes.
   */
  @api
  get hasValidContext() {
    return this.parsedContext !== null && !this.hasError;
  }

  /**
   * @description Plugin label for display.
   * @returns {string}
   */
  get cardTitle() {
    return "Top Error Integrations";
  }
}
