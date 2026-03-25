import { LightningElement, api, track } from "lwc";
import { getConstructor } from "c/iefDynamicLoader";
import getActiveCardPlugins from "@salesforce/apex/IntegrationHealthController.getActiveCardPlugins";

/**
 * @description Dashboard host that dynamically renders active CARD plugins
 * using lwc:is with constructor references from the dynamic loader.
 * Core NEVER static imports any plugin LWC.
 */
export default class IefDashboardHost extends LightningElement {
  /**
   * Refresh interval in milliseconds. If > 0, resolveCards() is called
   * on this interval. Exposed as a targetConfig property.
   * @type {number}
   */
  @api refreshInterval = 0;

  /** @type {boolean} Loading state */
  @track isLoading = true;

  /** @type {Array} Resolved card entries with ctor references */
  @track cardEntries = [];

  /** @type {number|null} Interval handle */
  _intervalHandle = null;

  connectedCallback() {
    this.loadPlugins();
    if (this.refreshInterval > 0) {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this._intervalHandle = setInterval(() => {
        this.loadPlugins();
      }, this.refreshInterval);
    }
  }

  disconnectedCallback() {
    if (this._intervalHandle !== null) {
      clearInterval(this._intervalHandle);
      this._intervalHandle = null;
    }
  }

  /**
   * @description Loads active CARD plugins from Apex and resolves their constructors.
   */
  async loadPlugins() {
    this.isLoading = true;
    try {
      const plugins = await getActiveCardPlugins();
      this.resolveCards(plugins || []);
    } catch (error) {
      console.error("[iefDashboardHost] Error loading plugins:", error);
      this.cardEntries = [];
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Resolves active CARD plugins. For each enabled CARD record,
   * looks up the constructor in the dynamic loader. Records with a registered
   * constructor get rendered via lwc:is; those without get the placeholder.
   * @param {Array} plugins - Array of plugin info objects from Apex (already filtered to Enabled__c = TRUE)
   */
  resolveCards(plugins) {
    this.cardEntries = plugins
      .map((plugin) => {
        const ctor = getConstructor(plugin.componentName);
        return {
          name: plugin.componentName,
          label: plugin.name || plugin.label,
          order: plugin.order,
          hasCtor: ctor !== null,
          ctor: ctor,
          contextData: JSON.stringify({
            filters: {},
            pluginName: plugin.developerName
          })
        };
      })
      .sort((a, b) => (a.order || 0) - (b.order || 0));
  }

  /**
   * @description Whether there are any card entries to render.
   * @returns {boolean}
   */
  get hasCards() {
    return this.cardEntries && this.cardEntries.length > 0;
  }

  /**
   * @description Whether to show the empty state (no active plugins).
   * @returns {boolean}
   */
  get showEmptyState() {
    return !this.isLoading && !this.hasCards;
  }

  /**
   * @description Default label for empty state.
   * @returns {string}
   */
  get emptyStateLabel() {
    return "No active card plugins registered";
  }
}
