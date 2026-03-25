import { LightningElement, api, track } from "lwc";
import getTopErrorIntegrations from "@salesforce/apex/IntegrationHealthController.getTopErrorIntegrations";

/**
 * @description Card implementation for the Top Errors plugin.
 * Fetches top error integrations and renders the ranked list.
 * This component is dynamically rendered via lwc:is — never static-imported by core.
 */
export default class IefTopErrorsCardImpl extends LightningElement {
  /** @type {string} JSON string with plugin context data */
  @api contextData = "";

  /** @type {Object} Parsed context object */
  parsedContext = null;

  /** @type {boolean} Whether data is loading */
  @track isLoading = true;

  /** @type {boolean} Whether an error occurred */
  @track hasError = false;

  /** @type {string} Error message */
  @track errorMessage = "";

  /** @type {Array} Top error integrations from Apex */
  @track integrations = [];

  connectedCallback() {
    this._parseContextData();
    this._fetchData();
  }

  /**
   * @description Parses the contextData JSON string safely.
   * @private
   */
  _parseContextData() {
    if (!this.contextData || this.contextData === "") {
      this.parsedContext = {};
      return;
    }

    try {
      this.parsedContext = JSON.parse(this.contextData);
    } catch {
      this.hasError = true;
      this.errorMessage = "Invalid context data received";
      this.parsedContext = null;
    }
  }

  /**
   * @description Fetches top error integrations from Apex.
   * @private
   */
  async _fetchData() {
    this.isLoading = true;
    this.hasError = false;

    try {
      const result = await getTopErrorIntegrations({ topN: 5 });
      this.integrations = result || [];
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || "Failed to load error data";
      this.integrations = [];
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

  /**
   * @description Whether there is integration data to display.
   * @returns {boolean}
   */
  get hasIntegrations() {
    return this.integrations && this.integrations.length > 0;
  }
}
