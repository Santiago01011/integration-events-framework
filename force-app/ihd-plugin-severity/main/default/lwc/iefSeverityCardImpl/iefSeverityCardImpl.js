import { LightningElement, api, track } from "lwc";
import getSeverityCounts from "@salesforce/apex/IntegrationHealthController.getSeverityCounts";

/**
 * @description Card implementation for the Severity Breakdown plugin.
 * Receives PluginContext from dashboard and fetches severity data with filters.
 * This component is dynamically rendered via lwc:is — never static-imported by core.
 *
 * PluginContext contract:
 * {
 *   pluginName: string,
 *   filters: { startDate, endDate, severity[], integrationCode },
 *   location: string,
 *   refreshToken: string,
 *   capabilities: { canExport, canFilter, canRefresh }
 * }
 */
export default class IefSeverityCardImpl extends LightningElement {
  /** @type {string} Internal storage for contextData */
  _contextData = "";

  /** @type {Object} Parsed PluginContext */
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
    this._parseAndFetch();
  }

  /**
   * @description Setter for contextData — re-fetches when context changes.
   * Dashboard updates contextData when filters change.
   */
  @api
  set contextData(value) {
    this._contextData = value;
    if (this.isConnected) {
      this._parseAndFetch();
    }
  }

  get contextData() {
    return this._contextData;
  }

  /**
   * @description Parses context and fetches data with filters.
   * @private
   */
  _parseAndFetch() {
    this._parseContextData();
    if (!this.hasError) {
      this._fetchData();
    }
  }

  /**
   * @description Parses the contextData JSON string safely.
   * @private
   */
  _parseContextData() {
    this.hasError = false;
    this.errorMessage = "";

    if (!this.contextData || this.contextData === "") {
      this.parsedContext = { filters: {} };
      return;
    }

    try {
      this.parsedContext = JSON.parse(this.contextData);
      if (!this.parsedContext.filters) {
        this.parsedContext.filters = {};
      }
    } catch {
      this.hasError = true;
      this.errorMessage = "Invalid context data received";
      this.parsedContext = { filters: {} };
    }
  }

  /**
   * @description Fetches severity counts from Apex with filters.
   * @private
   */
  async _fetchData() {
    this.isLoading = true;
    this.hasError = false;

    try {
      const filters = this.parsedContext?.filters || {};
      const result = await getSeverityCounts({ filters });
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

  /**
   * @description Handles card click event from the base plugin card.
   */
  handleCardClick() {
    this.dispatchEvent(
      new CustomEvent("pluginclick", {
        detail: {
          pluginName: "Severity_Card",
          severity: null
        }
      })
    );
  }
}
