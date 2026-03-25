import { LightningElement, api, track } from "lwc";
import { getConstructor } from "c/iefDynamicLoader";

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
    this.resolveCards();
    if (this.refreshInterval > 0) {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this._intervalHandle = setInterval(() => {
        this.resolveCards();
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
   * @description Resolves active CARD plugins. For each enabled CARD record,
   * looks up the constructor in the dynamic loader. Records with a registered
   * constructor get rendered via lwc:is; those without get the placeholder.
   * Currently uses a simulated metadata list — will be replaced with @wire
   * when IHD_Plugin__mdt is queryable.
   */
  resolveCards() {
    this.isLoading = true;
    try {
      const plugins = this._getActivePlugins();
      this.cardEntries = plugins.map((plugin) => {
        const ctor = getConstructor(plugin.lwcName);
        return {
          name: plugin.lwcName,
          label: plugin.label,
          order: plugin.order,
          hasCtor: ctor !== null,
          ctor: ctor,
          contextData: JSON.stringify({
            filters: {},
            pluginName: plugin.developerName
          })
        };
      });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Returns active CARD plugin metadata.
   * Placeholder until @wire(IHD_Plugin__mdt) is wired up.
   * @returns {Array<{developerName: string, lwcName: string, label: string, order: number}>}
   * @private
   */
  _getActivePlugins() {
    // Placeholder — will be replaced with wired Apex or direct @wire to custom metadata
    return [];
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
