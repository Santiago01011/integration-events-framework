import { LightningElement, api, track } from "lwc";
import { getConstructor } from "c/iefDynamicLoader";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext
} from "lightning/messageService";
import IEF_CARD_REGISTRY from "@salesforce/messageChannel/IEF_Card_Registry__c";
import getActiveCardPlugins from "@salesforce/apex/IntegrationHealthController.getActiveCardPlugins";

/**
 * @description Dashboard host that dynamically renders active CARD plugins
 * using lwc:is with constructor references from iefDynamicLoader.
 *
 * Registration flow:
 * 1. Shells register at module scope: registerCard("name", ctor) in their own package
 * 2. Shells publish via LMS: "I registered card X"
 * 3. Dashboard subscribes to LMS channel and receives registration messages
 * 4. Dashboard calls loadPlugins() to re-resolve constructors
 * 5. Dashboard renders via lwc:is={ctor}
 *
 * Core NEVER static imports any plugin LWC.
 * Plugins register themselves at module scope via registerCard() from core.
 * LMS provides cross-component notification without timing dependencies.
 */
export default class IefDashboardHost extends LightningElement {
  /** @type {number} Refresh interval in milliseconds */
  @api refreshInterval = 0;

  /** @type {Object} Current filter state from parent */
  @api filters = {};

  /** @type {boolean} Loading state */
  @track isLoading = true;

  /** @type {Array} Resolved card entries with ctor references */
  @track cardEntries = [];

  /** @type {MessageContext} LMS context */
  messageContext = MessageContext;

  /** @type {Function|null} LMS subscription */
  _subscription = null;

  /** @type {number|null} Refresh interval handle */
  _intervalHandle = null;

  connectedCallback() {
    // Subscribe to card registration messages
    this._subscription = subscribe(
      this.messageContext,
      IEF_CARD_REGISTRY,
      (message) => this.handleCardRegistration(message),
      { scope: APPLICATION_SCOPE }
    );

    // Initial load
    this.loadPlugins();

    // Auto-refresh if configured
    if (this.refreshInterval > 0) {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this._intervalHandle = setInterval(() => {
        this.loadPlugins();
      }, this.refreshInterval);
    }
  }

  disconnectedCallback() {
    if (this._subscription) {
      unsubscribe(this._subscription);
      this._subscription = null;
    }
    if (this._intervalHandle !== null) {
      clearInterval(this._intervalHandle);
      this._intervalHandle = null;
    }
  }

  /**
   * @description Handles card registration messages from shells.
   * When a shell registers a card, re-resolve all cards.
   * @param {Object} message - LMS message with cardName, cardLabel, action
   */
  handleCardRegistration(message) {
    if (message && message.action === "register") {
      // Shell registered a card — re-resolve to pick up new constructor
      this.loadPlugins();
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

  get hasCards() {
    return this.cardEntries && this.cardEntries.length > 0;
  }

  get showEmptyState() {
    return !this.isLoading && !this.hasCards;
  }

  get emptyStateLabel() {
    return "No active card plugins registered";
  }
}
