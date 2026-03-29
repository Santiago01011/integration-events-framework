import { LightningElement, api, track, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import IEF_PLUGIN_ACTIONS from "@salesforce/messageChannel/IEF_Plugin_Actions__c";
import getTopErrorIntegrations from "@salesforce/apex/IntegrationHealthController.getTopErrorIntegrations";

/**
 * @description Card implementation for the Top Errors plugin.
 * Receives PluginContext from dashboard and fetches error integrations with filters.
 * This component is dynamically rendered via lwc:is — never static-imported by core.
 *
 * PluginContext contract:
 * {
 *   pluginName: string,
 *   filters: {
 *     search?: string,
 *     observationType?: string,
 *     integrationCode?: string,
 *     correlationId?: string,
 *     fromOccurredAt?: string | null,
 *     toOccurredAt?: string | null
 *   },
 *   location: 'dashboard' | 'record' | 'app',
 *   refreshToken: string,
 *   capabilities: { canExport: boolean, canFilter: boolean, canRefresh: boolean }
 * }
 */
export default class IefTopErrorsCardImpl extends LightningElement {
  /** @type {string} Internal storage for contextData */
  _contextData = "";

  /** @type {Object} LMS message context for publishing actions */
  @wire(MessageContext)
  messageContext;

  /** @type {Object} Parsed PluginContext */
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
   * @description Fetches top error integrations from Apex with filters.
   * @private
   */
  async _fetchData() {
    this.isLoading = true;
    this.hasError = false;

    try {
      const filters = this.parsedContext?.filters || {};
      const result = await getTopErrorIntegrations({
        topN: 5,
        filters
      });
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
    return "Top Error Integrations";
  }

  /**
   * @description Whether there is integration data to display.
   * @returns {boolean}
   */
  get hasIntegrations() {
    return this.integrations && this.integrations.length > 0;
  }

  /**
   * @description Handles integrationclick event from child component.
   * @param {CustomEvent} event - Event with integrationCode in detail
   */
  handleIntegrationClickFromChild(event) {
    const integrationCode = event.detail?.integrationCode;
    if (!integrationCode || !this.messageContext) return;

    publish(this.messageContext, IEF_PLUGIN_ACTIONS, {
      pluginName: "TopErrors_Card",
      action: "navigate_to_filters",
      payload: {
        integrationCode: integrationCode
      }
    });
  }
}
