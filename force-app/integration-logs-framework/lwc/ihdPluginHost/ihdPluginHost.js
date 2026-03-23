import { LightningElement, api } from "lwc";

/**
 * @description Host component for rendering plugin cards in the Summary tab.
 * Receives plugin metadata and data, renders the appropriate LWC component
 * via a switch-based template. Plugins are discovered dynamically but rendered
 * via explicit template bindings (LWC limitation: no dynamic `is` attribute).
 */
export default class IhdPluginHost extends LightningElement {
  /** @type {Object} Plugin info with name, componentName, data, etc. */
  @api plugin;

  /** @type {Object} Filter context from the dashboard */
  @api filters;

  /** @type {boolean} Loading state */
  @api isLoading = false;

  get pluginName() {
    return this.plugin?.componentName || "";
  }

  get pluginData() {
    return this.plugin?.data;
  }

  get hasPlugin() {
    return !!this.plugin;
  }

  // Add getters for each known plugin component
  get isSeverityBreakdown() {
    return this.pluginName === "c-ihd-severity-breakdown";
  }

  get isTopErrorIntegrations() {
    return this.pluginName === "c-ihd-top-error-integrations";
  }

  // Handle plugin click events
  handlePluginClick(event) {
    this.dispatchEvent(
      new CustomEvent("pluginclick", {
        detail: {
          pluginName: this.plugin?.name,
          componentName: this.pluginName,
          ...event.detail
        }
      })
    );
  }

  // Handle severity click
  handleSeverityClick(event) {
    this.dispatchEvent(
      new CustomEvent("pluginclick", {
        detail: {
          pluginName: this.plugin?.name,
          componentName: this.pluginName,
          severity: event.detail?.severity
        }
      })
    );
  }

  // Handle top error click
  handleTopErrorClick(event) {
    this.dispatchEvent(
      new CustomEvent("pluginclick", {
        detail: {
          pluginName: this.plugin?.name,
          componentName: this.pluginName,
          integrationCode: event.detail?.integrationCode
        }
      })
    );
  }
}
