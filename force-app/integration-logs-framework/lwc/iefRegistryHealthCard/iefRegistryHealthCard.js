import { LightningElement, api } from "lwc";
import { parseContextData } from "c/iefPluginContext";
import getCardData from "@salesforce/apex/IEF_RegistryHealthCardPlugin.getCardData";

/**
 * @description Card implementation for the Registry Health reference plugin.
 * Receives PluginContext from dashboard and fetches effective composition.
 * Dynamically rendered via lwc:is — never static-imported by dashboard.
 *
 * PluginContext contract:
 * {
 *   pluginName: string,
 *   filters: {},
 *   location: 'dashboard' | 'record' | 'app',
 *   refreshToken: string,
 *   capabilities: { canExport, canFilter, canRefresh }
 * }
 * Filters are ignored per C3 — this card always returns the full composition.
 */
export default class IefRegistryHealthCard extends LightningElement {
  _contextData = "";
  parsedContext = null;
  isLoading = true;
  hasError = false;
  errorMessage = "";
  entries = [];

  connectedCallback() {
    this._parseAndFetch();
  }

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

  _parseAndFetch() {
    const { context, error } = parseContextData(this.contextData);
    this.parsedContext = context;
    this.hasError = error !== null;
    this.errorMessage = error || "";
    if (!this.hasError) {
      this._fetchData();
    }
  }

  async _fetchData() {
    this.isLoading = true;
    this.hasError = false;
    try {
      const filters = this.parsedContext?.filters || {};
      const result = await getCardData({ filters });
      this.entries = result || [];
    } catch (error) {
      this.hasError = true;
      this.errorMessage =
        error.body?.message || "Failed to load registry composition";
      this.entries = [];
    } finally {
      this.isLoading = false;
    }
  }

  @api
  get hasValidContext() {
    return this.parsedContext !== null && !this.hasError;
  }

  get cardTitle() {
    return "Registry Health";
  }

  get hasEntries() {
    return this.entries && this.entries.length > 0;
  }

  get rows() {
    return this.entries.map((e) => ({
      ...e,
      key: e.developerName,
      badgeClass: this._badgeClass(e.status),
      statusLabel: e.status || "UNKNOWN"
    }));
  }

  _badgeClass(status) {
    switch (status) {
      case "ACTIVE":
        return "slds-badge slds-theme_success";
      case "ACTIVE_LWC":
        return "slds-badge slds-theme_info";
      case "FAILED":
        return "slds-badge slds-theme_error";
      case "ORPHAN":
        return "slds-badge slds-theme_warning";
      case "SKIPPED_VERSION_MISMATCH":
      case "SKIPPED":
        return "slds-badge slds-theme_offline";
      default:
        return "slds-badge";
    }
  }
}
