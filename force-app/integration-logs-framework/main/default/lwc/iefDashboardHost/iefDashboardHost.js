import { LightningElement, api, track } from "lwc";
import { getConstructor } from "c/iefDynamicLoader";
import getActiveCardPlugins from "@salesforce/apex/IntegrationHealthController.getActiveCardPlugins";

/**
 * @description Dashboard host that dynamically renders active CARD plugins
 * using lwc:is with constructor references from iefDynamicLoader.
 *
 * Registration flow:
 * 1. Shells register at module scope: registerCard("name", ctor)
 * 2. Dashboard discovers plugins via getActiveCardPlugins() Apex
 * 3. Dashboard resolves constructors via getConstructor() from single registry
 * 4. Dashboard renders via lwc:is={ctor}
 *
 * Core NEVER static imports any plugin LWC.
 * Plugins register themselves at module scope via registerCard().
 */
export default class IefDashboardHost extends LightningElement {
  /**
   * Refresh interval in milliseconds. If > 0, resolveCards() is called
   * on this interval. Exposed as a targetConfig property.
   * @type {number}
   */
  @api refreshInterval = 0;

  /**
   * Current filter state from parent dashboard.
   * Propagated to cards via PluginContext.
   * @type {Object}
   */
  @api filters = {};

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
   * @param {Array} plugins - Array of plugin info objects from Apex
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
            pluginName: plugin.developerName,
            filters: this.filters,
            location: "dashboard",
            refreshToken: Date.now().toString(),
            capabilities: {
              canExport: true,
              canFilter: true,
              canRefresh: true
            }
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
