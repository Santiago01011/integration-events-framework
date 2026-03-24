import { LightningElement, api, track } from "lwc";
import getCardPluginData from "@salesforce/apex/IntegrationHealthController.getCardPluginData";
import SeverityBreakdown from "c/ihdSeverityBreakdown";
import TopErrorIntegrations from "c/ihdTopErrorIntegrations";

/**
 * @description Component registry mapping componentName strings to imported LWC classes.
 * Add new plugin imports and entries here to register them with the host.
 */
const COMPONENT_REGISTRY = {
  "c-ihd-severity-breakdown": SeverityBreakdown,
  "c-ihd-top-error-integrations": TopErrorIntegrations
};

/**
 * @description Host component for rendering plugin cards in the Summary tab.
 * Receives plugin metadata, fetches plugin data dynamically if not provided,
 * and renders the appropriate LWC component via a registry-based template.
 * Plugins are discovered dynamically but rendered via explicit template bindings
 * (LWC limitation: no dynamic `is` attribute).
 */
export default class IhdPluginHost extends LightningElement {
  /** @type {Object} Filter context from the dashboard */
  @api filters;

  /** @type {boolean} Loading state */
  @api isLoading = false;

  /** @type {Object} Plugin info with name, componentName, data, etc. */
  _plugin = null;

  /** @type {Object} Fetched plugin data from Apex */
  @track pluginDataInternal = null;

  /** @type {boolean} Whether data is being fetched */
  @track isFetchingData = false;

  /**
   * @description Getter for plugin property.
   * @returns {Object} The plugin object
   */
  @api
  get plugin() {
    return this._plugin;
  }

  /**
   * @description Setter for plugin property.
   * If data is provided, use it directly. Otherwise, fetch from Apex.
   * @param {Object} value - The plugin object
   */
  set plugin(value) {
    this._plugin = value;
    // Reset internal state
    this.pluginDataInternal = null;
    this.isFetchingData = false;

    if (!value || !value.developerName) {
      return;
    }

    // If data is explicitly provided (even if null/empty), use it
    if (value.data !== undefined) {
      this.pluginDataInternal = value.data;
    } else {
      // Fetch data from Apex using DeveloperName
      this.fetchPluginData(value.developerName);
    }
  }

  get pluginName() {
    return this._plugin?.componentName || "";
  }

  get pluginData() {
    // Return fetched data if available, otherwise fall back to passed data
    return this.pluginDataInternal !== null
      ? this.pluginDataInternal
      : this._plugin?.data;
  }

  get hasPlugin() {
    return !!this._plugin;
  }

  /**
   * @description Whether the plugin's componentName is in the registry.
   * @returns {boolean}
   */
  get isKnownPlugin() {
    return this.pluginName in COMPONENT_REGISTRY;
  }

  /**
   * @description Whether this is the severity breakdown plugin.
   * @returns {boolean}
   */
  get isSeverityBreakdown() {
    return this.pluginName === "c-ihd-severity-breakdown";
  }

  /**
   * @description Whether this is the top error integrations plugin.
   * @returns {boolean}
   */
  get isTopErrorIntegrations() {
    return this.pluginName === "c-ihd-top-error-integrations";
  }

  /**
   * @description Fetches data for the plugin from Apex.
   * @param {string} pluginName - The DeveloperName of the plugin
   */
  async fetchPluginData(pluginName) {
    this.isFetchingData = true;
    try {
      const data = await getCardPluginData({
        pluginName,
        filters: this.filters
      });
      this.pluginDataInternal = data;
    } catch (error) {
      this.pluginDataInternal = null;
      // eslint-disable-next-line no-console
      console.error(
        `Failed to fetch data for plugin ${pluginName}:`,
        error?.body?.message || error?.message || error
      );
    } finally {
      this.isFetchingData = false;
    }
  }

  /**
   * @description Whether the plugin has data to preview in the fallback card.
   * @returns {boolean}
   */
  get hasDataPreview() {
    const data = this.pluginData;
    if (data === null || data === undefined) return false;
    if (Array.isArray(data)) return data.length > 0;
    if (typeof data === "object") return Object.keys(data).length > 0;
    return true;
  }

  /**
   * @description Whether pluginData is a plain object (not array).
   * @returns {boolean}
   */
  get isDataObject() {
    const data = this.pluginData;
    return data !== null && typeof data === "object" && !Array.isArray(data);
  }

  /**
   * @description Converts pluginData object entries into iterable key-value pairs.
   * @returns {Array<{key: string, value: string}>}
   */
  get dataEntries() {
    const data = this.pluginData;
    if (!data || typeof data !== "object" || Array.isArray(data)) return [];
    return Object.entries(data).map(([key, value]) => ({
      key,
      value: typeof value === "object" ? JSON.stringify(value) : String(value)
    }));
  }

  /**
   * @description Formats non-object plugin data as a JSON string.
   * @returns {string}
   */
  get pluginDataFormatted() {
    const data = this.pluginData;
    if (data === null || data === undefined) return "";
    try {
      return JSON.stringify(data, null, 2);
    } catch {
      return String(data);
    }
  }

  /**
   * @description Generic handler for all plugin click events.
   * Forwards the event detail with plugin metadata.
   * @param {CustomEvent} event - Click event from a plugin component
   */
  handlePluginClick(event) {
    this.dispatchEvent(
      new CustomEvent("pluginclick", {
        detail: {
          pluginName: this._plugin?.name,
          componentName: this.pluginName,
          ...event.detail
        }
      })
    );
  }
}
