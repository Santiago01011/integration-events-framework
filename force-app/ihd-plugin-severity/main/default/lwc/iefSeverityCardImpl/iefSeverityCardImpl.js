import { LightningElement, api, track } from "lwc";
import getSeverityCounts from "@salesforce/apex/IntegrationHealthController.getSeverityCounts";

/**
 * @description Card implementation for the Severity Breakdown plugin.
 * Fetches severity data and renders the donut chart visualization.
 * This component is dynamically rendered via lwc:is — never static-imported by core.
 */
export default class IefSeverityCardImpl extends LightningElement {
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

  /** @type {Array} Severity counts from Apex */
  @track severityCounts = [];

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
   * @description Fetches severity counts from Apex.
   * @private
   */
  async _fetchData() {
    this.isLoading = true;
    this.hasError = false;

    try {
      const result = await getSeverityCounts();
      this.severityCounts = result || [];
    } catch (error) {
      this.hasError = true;
      this.errorMessage = error.body?.message || "Failed to load severity data";
      this.severityCounts = [];
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Whether the parsed context is valid.
   * @returns {boolean}
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
    return "Severity Breakdown";
  }

  /**
   * @description Whether there is severity data to display.
   * @returns {boolean}
   */
  get hasSeverityData() {
    return this.severityCounts && this.severityCounts.length > 0;
  }
}
