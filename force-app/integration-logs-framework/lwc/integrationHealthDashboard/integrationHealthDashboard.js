import { LightningElement, api, wire, track } from "lwc";
import { getConstructor } from "c/iefDynamicLoader";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext
} from "lightning/messageService";
import IEF_CARD_REGISTRY from "@salesforce/messageChannel/IEF_Card_Registry__c";
import IEF_PLUGIN_ACTIONS from "@salesforce/messageChannel/IEF_Plugin_Actions__c";
import getRecentLogs from "@salesforce/apex/IntegrationHealthController.getRecentLogs";
import getLogDetail from "@salesforce/apex/IntegrationHealthController.getLogDetail";
import getIntegrationSummaries from "@salesforce/apex/IntegrationHealthController.getIntegrationSummaries";
import getActiveCardPlugins from "@salesforce/apex/IntegrationHealthController.getActiveCardPlugins";
import isAdminUser from "@salesforce/apex/IntegrationHealthController.isAdminUser";
import canManagePlugins from "@salesforce/apex/IntegrationHealthController.canManagePlugins";
import canEditLogObservationType from "@salesforce/apex/IntegrationHealthController.canEditLogObservationType";
import deleteLog from "@salesforce/apex/IntegrationHealthController.deleteLog";
import updateLogObservation from "@salesforce/apex/IntegrationHealthController.updateLogObservation";
import LightningConfirm from "lightning/confirm";
import LightningPrompt from "lightning/prompt";
import logsApi from "c/utilsLogsApi";

// Custom Labels
import IHD_Tab_Summary from "@salesforce/label/c.IHD_Tab_Summary";
import IHD_Tab_Integrations from "@salesforce/label/c.IHD_Tab_Integrations";
import IHD_Tab_Filters from "@salesforce/label/c.IHD_Tab_Filters";
import IHD_Tab_Admin from "@salesforce/label/c.IHD_Tab_Admin";
import IHD_System_Pulse from "@salesforce/label/c.IHD_System_Pulse";
import IHD_Loading from "@salesforce/label/c.IHD_Loading";
import IHD_Error_Loading_Summaries from "@salesforce/label/c.IHD_Error_Loading_Summaries";
import IHD_View_Grouped from "@salesforce/label/c.IHD_View_Grouped";
import IHD_View_Detailed from "@salesforce/label/c.IHD_View_Detailed";

const REFRESH_DEBOUNCE_MS = 1500;

export default class IntegrationHealthDashboard extends LightningElement {
  // Expose labels for template binding
  labels = {
    IHD_Tab_Summary,
    IHD_Tab_Integrations,
    IHD_Tab_Filters,
    IHD_Tab_Admin,
    IHD_System_Pulse,
    IHD_Loading,
    IHD_Error_Loading_Summaries,
    IHD_View_Grouped,
    IHD_View_Detailed
  };

  pluginGridSpans = {};

  get columns() {
    let actions = [{ label: "View Details", name: "view_details" }];

    if (this.canEditObservationType) {
      actions.push({ label: "Change Status (Type)", name: "change_status" });
    }

    if (this.isAdmin) {
      actions.push({
        label: "Delete Log",
        name: "delete_log",
        variant: "destructive"
      });
    }

    return [
      ...logsApi.BASE_COLUMNS,
      {
        type: "action",
        typeAttributes: {
          rowActions: actions
        }
      }
    ];
  }
  @track isLoading = false;
  @track summaryLoading = false;
  @track hasMore = false;

  @track rows = [];
  @track summaries = [];
  @track activePlugins = [];

  currentFilters = {};
  lastOccurredAt;
  lastId;
  pageSize = 20;

  showDetailDrawer = false;
  selectedRecord;

  searchValue = "";
  observationType = "";
  integrationCode = "";
  correlationId = "";
  fromOccurredAt;
  toOccurredAt;
  @track includeUnregistered = true;
  @track expandByAttributes = false;
  @track summaryVersion = 0;
  typeToSeverity = {};
  @track isAdmin = false;
  @track canManagePlugins = false;
  @track canEditObservationType = false;
  @track isLiveConnected = false;
  @track isLiveStale = false;

  /** @type {Map<string, boolean>} Methods blocked due to persistent permission errors */
  _permBlocked = new Map();

  /** @type {boolean} Whether a permission error was shown this session */
  _permErrorShown = false;

  @wire(isAdminUser)
  wiredIsAdmin({ error, data }) {
    if (data !== undefined) {
      this.isAdmin = data;
    } else if (error) {
      this.isAdmin = false;
    }
  }

  @wire(canManagePlugins)
  wiredCanManagePlugins({ error, data }) {
    if (data !== undefined) {
      this.canManagePlugins = data;
    } else if (error) {
      this.canManagePlugins = false;
    }
  }

  @wire(canEditLogObservationType)
  wiredCanEditObservationType({ error, data }) {
    if (data !== undefined) {
      this.canEditObservationType = data;
    } else if (error) {
      this.canEditObservationType = false;
    }
  }

  /** @wire MessageContext for LMS */
  @wire(MessageContext)
  messageContext;

  /** @type {Function|null} LMS subscription for card registration */
  _cardRegistrySubscription = null;

  _debouncedRefreshAll;

  connectedCallback() {
    this._debouncedRefreshAll = logsApi.debounce(
      () => this._refreshAllImmediate(),
      REFRESH_DEBOUNCE_MS
    );

    // Subscribe to card registration messages
    this._subscribeToCardRegistry();

    // Subscribe to plugin action requests
    this._subscribeToPluginActions();

    this.loadInitialData();
    this.refreshSummaryData();
  }

  disconnectedCallback() {
    if (this._cardRegistrySubscription) {
      unsubscribe(this._cardRegistrySubscription);
      this._cardRegistrySubscription = null;
    }
    if (this._pluginActionsSubscription) {
      unsubscribe(this._pluginActionsSubscription);
      this._pluginActionsSubscription = null;
    }
  }

  /**
   * @description Subscribes to the IEF_Card_Registry LMS channel.
   * When a shell registers a card, re-resolve constructors.
   * @private
   */
  _subscribeToCardRegistry() {
    if (this.messageContext) {
      this._cardRegistrySubscription = subscribe(
        this.messageContext,
        IEF_CARD_REGISTRY,
        (message) => this.handleCardRegistration(message),
        { scope: APPLICATION_SCOPE }
      );
    }
  }

  /**
   * @description Handles card registration messages from shells.
   * When a shell registers a card, re-resolve plugins to pick up new constructors.
   * @param {Object} message - LMS message with cardName, cardLabel, action
   */
  handleCardRegistration(message) {
    if (message && message.action === "register") {
      this.fetchActivePlugins();
    }
  }

  /**
   * @description Subscribes to the IEF_Plugin_Actions LMS channel.
   * Receives action requests from plugins (e.g. navigation, refresh).
   * @private
   */
  _subscribeToPluginActions() {
    if (this.messageContext) {
      this._pluginActionsSubscription = subscribe(
        this.messageContext,
        IEF_PLUGIN_ACTIONS,
        (message) => this.handlePluginAction(message),
        { scope: APPLICATION_SCOPE }
      );
    }
  }

  /**
   * @description Handles action requests from plugins via LMS.
   * Routes actions to appropriate dashboard handlers.
   * @param {Object} message - LMS message with pluginName, action, payload
   */
  handlePluginAction(message) {
    if (!message || !message.action) {
      return;
    }

    const { action, payload } = message;

    switch (action) {
      case "navigate_to_filters":
        // Generic filter navigation - payload contains filter fields
        if (payload) {
          if (payload.fromDate) {
            this.fromOccurredAt = payload.fromDate;
          }
          if (payload.toDate) {
            this.toOccurredAt = payload.toDate;
          }
          if (payload.integrationCode) {
            this.integrationCode = payload.integrationCode;
          }
          if (payload.searchTerm) {
            this.searchValue = payload.searchTerm;
          }
        }
        this.loadInitialData();
        this.activeTab = "filters";
        break;

      case "refresh_dashboard":
        this.refreshSummaryData();
        break;

      default:
        // Unknown action - ignore silently
        break;
    }
  }

  // --- Event Hub Handlers ---

  /**
   * @description Handles new rows from the event hub.
   * @param {CustomEvent} event - Event with transformed rows in detail
   */
  handleNewLiveRows(event) {
    const newRows = event.detail || [];
    this.rows = [...newRows, ...this.rows];
  }

  /**
   * @description Handles activity notifications from the event hub.
   * Refreshes all summary-level data in parallel.
   */
  handleLiveActivity() {
    this.refreshSummaryData();
  }

  /**
   * @description Handles status changes from the event hub.
   * @param {CustomEvent} event - Event with isConnected in detail
   */
  handleLiveStatusChange(event) {
    this.isLiveConnected = event.detail.isConnected;
    this.isLiveStale = event.detail.isStale;
  }

  /**
   * @description Handles the 'filterschanged' event from c-ihd-filters.
   * Updates individual filter properties and the currentFilters map for plugin propagation.
   */
  handleFiltersChanged(event) {
    const {
      search,
      observationType,
      integrationCode,
      correlationId,
      from,
      to
    } = event.detail || {};
    this.searchValue = search || "";
    this.observationType = observationType || "";
    this.integrationCode = integrationCode || "";
    this.correlationId = correlationId || "";
    this.fromOccurredAt = from || null;
    this.toOccurredAt = to || null;
    this.currentFilters = {
      search: this.searchValue,
      observationType: this.observationType,
      integrationCode: this.integrationCode,
      correlationId: this.correlationId,
      fromOccurredAt: this.fromOccurredAt,
      toOccurredAt: this.toOccurredAt
    };
    this.loadInitialData();
  }

  /**
   * @description Handles the 'refresh' event from child components - immediate, no debounce
   */
  handleRefresh() {
    this._refreshAllImmediate();
  }

  /**
   * @description Public refresh method - uses debounce to prevent rapid successive calls
   */
  refreshAll() {
    if (this._debouncedRefreshAll) {
      this._debouncedRefreshAll();
    } else {
      this._refreshAllImmediate();
    }
  }

  /**
   * @description Clears all permission error blocks so methods retry on next call.
   * Called on explicit user refresh.
   */
  _clearPermissionBlocks() {
    this._permBlocked.clear();
    this._permErrorShown = false;
  }

  /**
   * @description Internal refresh implementation - fetches logs and summaries in parallel.
   * Clears permission blocks so user gets a fresh attempt after explicit refresh.
   */
  async _refreshAllImmediate() {
    this._clearPermissionBlocks();
    this.isLoading = true;
    try {
      const eventHub = this.template.querySelector("c-ihd-event-hub");
      if (eventHub) {
        eventHub.refresh();
      }

      await Promise.all([
        this.fetchAndSetLogs({ append: false, force: true }),
        this.refreshSummaryData()
      ]);
    } catch (error) {
      logsApi.showError(
        this,
        "Error refreshing data",
        logsApi.resolveErrorMessage(error)
      );
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Fetches summaries imperatively to bypass wire cache on refresh
   */
  async fetchSummariesImperative() {
    if (this._permBlocked.get("summaries")) return;

    this.summariesError = undefined;
    try {
      const data = await getIntegrationSummaries({
        includeUnregistered: this.includeUnregistered,
        expandByAttributes: this.expandByAttributes
      });
      this.summaries = [...data];
      this.summaryVersion++;
      this.lastUpdated = new Date().toISOString();
    } catch (error) {
      this.summariesError = error;
      if (this._isPermissionError(error)) {
        this._permBlocked.set("summaries", true);
        this._showPermissionErrorOnce(
          "Cannot access integration summaries due to missing permissions."
        );
      } else {
        logsApi.showError(
          this,
          "Error loading summaries",
          logsApi.resolveErrorMessage(error)
        );
      }
    }
  }

  /**
   * @description Checks if an error is a persistent permission/FLS error that won't resolve on retry.
   * @param {object} error - The error object from Apex
   * @returns {boolean}
   */
  _isPermissionError(error) {
    const msg = logsApi.resolveErrorMessage(error).toLowerCase();
    return (
      msg.includes("insufficient access") ||
      msg.includes("invalid field") ||
      (msg.includes("sobject type") && msg.includes("is not supported"))
    );
  }

  /**
   * @description Shows a single permission error toast and marks as shown.
   */
  _showPermissionErrorOnce(detail) {
    if (!this._permErrorShown) {
      this._permErrorShown = true;
      logsApi.showError(
        this,
        "Missing Permissions",
        detail +
          " Contact your admin to assign the Integration Dashboard permission set."
      );
    }
  }

  /**
   * @description Fetches active card plugins from the registry for dynamic rendering.
   * Resolves constructors from iefDynamicLoader for lwc:is rendering.
   */
  async fetchActivePlugins() {
    if (this._permBlocked.get("plugins")) return;

    try {
      const data = await getActiveCardPlugins();
      const plugins = (data || []).sort(
        (a, b) => (a.order || 0) - (b.order || 0)
      );

      // Resolve constructors for lwc:is rendering
      this.activePlugins = plugins.map((plugin) => {
        const ctor = getConstructor(plugin.componentName);
        const gridSpan =
          plugin.gridSpan || this.pluginGridSpans[plugin.componentName] || 1;
        const gridClass = this._getGridSpanClass(gridSpan);
        const gridWidth = (gridSpan / 3) * 100;
        const gridStyle = `flex: 0 0 ${gridWidth}%; max-width: ${gridWidth}%;`;
        return {
          ...plugin,
          hasCtor: ctor !== null,
          ctor: ctor,
          gridSpan,
          gridClass,
          gridStyle,
          contextData: JSON.stringify({
            pluginName: plugin.developerName,
            filters: this.currentFilters,
            location: "dashboard",
            refreshToken: Date.now().toString(),
            capabilities: {
              canExport: true,
              canFilter: true,
              canRefresh: true
            }
          })
        };
      });
    } catch (error) {
      this.activePlugins = [];
      if (this._isPermissionError(error)) {
        this._permBlocked.set("plugins", true);
        this._showPermissionErrorOnce(
          "Cannot access plugin registry due to missing permissions."
        );
      } else {
        logsApi.showError(
          this,
          "Error loading card plugins",
          logsApi.resolveErrorMessage(error)
        );
      }
    }
  }

  /**
   * @description Gets the CSS grid span class for a given column span.
   * Grid is 3 columns total. This creates appropriate sizing classes.
   * @param {number} span - Number of columns to span (1-3)
   * @returns {string} CSS class for grid span
   * @private
   */
  _getGridSpanClass(span) {
    // Custom grid classes for 3-column layout
    // Mobile: full width, Large: partial width based on span
    const spans = {
      1: "ihd-grid-1",
      2: "ihd-grid-2",
      3: "ihd-grid-3"
    };
    return spans[span] || "";
  }

  /**
   * @description Refreshes all summary-level data in parallel.
   */
  refreshSummaryData() {
    return Promise.all([
      this.fetchSummariesImperative(),
      this.fetchActivePlugins()
    ]);
  }

  async loadInitialData(force = false) {
    this.isLoading = true;
    this.rows = [];
    this.hasMore = false;

    try {
      await this.fetchAndSetLogs({ append: false, force });
    } catch (error) {
      logsApi.showError(
        this,
        "Error loading data",
        logsApi.resolveErrorMessage(error)
      );
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Handles the 'rowaction' event from c-ihd-table.
   * Manages view details, delete, and status change actions.
   * @param {CustomEvent} event - The row action event
   */
  async handleRowAction(event) {
    const action = event.detail.action;
    const row = event.detail.row;

    if (row._isFromEvent && action.name === "view_details") {
      // For live event rows, display details from local memory
      this.displayLocalDetails(row);
      return;
    }

    if (row._isFromEvent) {
      logsApi.showToast(
        this,
        "Event Record",
        "This record is from a recent event. Refresh the table to perform this action.",
        "warning"
      );
      return;
    }

    switch (action.name) {
      case "view_details":
        this.loadAndDisplayDetails(row.Id);
        break;
      case "delete_log":
        await this.handleDeleteLog(row);
        break;
      case "change_status":
        await this.handleChangeStatus(row);
        break;
      default:
        break;
    }
  }

  /**
   * @description Deletes a specific log record with confirmation.
   * @param {object} row - The row data representing the log record
   */
  async handleDeleteLog(row) {
    const confirmed = await LightningConfirm.open({
      message: `Are you sure you want to delete this log? This action cannot be undone.`,
      label: "Confirm Deletion",
      theme: "error"
    });

    if (confirmed) {
      this.isLoading = true;
      try {
        await deleteLog({ logId: row.Id });
        logsApi.showToast(
          this,
          "Success",
          "Log deleted successfully",
          "success"
        );
        this.refreshAll();
      } catch (error) {
        logsApi.showError(
          this,
          "Error deleting log",
          logsApi.resolveErrorMessage(error)
        );
      } finally {
        this.isLoading = false;
      }
    }
  }

  /**
   * @description Prompts the user to change the observation type of a log record.
   * @param {object} row - The row data representing the log record
   */
  async handleChangeStatus(row) {
    const newType = await LightningPrompt.open({
      message: "Enter the new Observation Type for this log:",
      label: "Change Status (Type)",
      defaultValue: row.ObservationType__c
    });

    if (newType !== null && newType !== row.ObservationType__c) {
      this.isLoading = true;
      try {
        await updateLogObservation({ logId: row.Id, newType });
        logsApi.showToast(this, "Success", "Log status updated", "success");
        this.refreshAll();
      } catch (error) {
        logsApi.showError(
          this,
          "Error updating log",
          logsApi.resolveErrorMessage(error)
        );
      } finally {
        this.isLoading = false;
      }
    }
  }

  /**
   * @description Handles the 'loadmore' event from c-ihd-table.
   * Fetches the next page of logs using primitive pagination parameters.
   */
  async handleLoadMoreData() {
    if (!this.hasMore || this.isLoading) {
      return;
    }
    this.isLoading = true;

    try {
      const data = await logsApi.fetchPage(
        getRecentLogs,
        {
          pageSize: this.pageSize,
          search: this.searchValue,
          fromOccurredAtStr: this.fromOccurredAt,
          toOccurredAtStr: this.toOccurredAt,
          lastOccurredAtStr: this.lastOccurredAt,
          lastId: this.lastId,
          correlationId: this.correlationId,
          observationType: this.observationType,
          integrationCode: this.integrationCode
        },
        { force: false }
      );

      if (data.typeToSeverity) {
        this.typeToSeverity = {
          ...this.typeToSeverity,
          ...data.typeToSeverity
        };
      }
      const newLogs = (data.records || []).map((row) =>
        logsApi.transformRow(row, this.typeToSeverity)
      );
      this.rows = [...this.rows, ...newLogs];
      this.hasMore = data.hasMore;
      this.lastOccurredAt = data.lastOccurredAt;
      this.lastId = data.lastId;
    } catch (error) {
      logsApi.showError(
        this,
        "Error loading more logs",
        logsApi.resolveErrorMessage(error)
      );
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Core data fetcher. Handles transformation of raw API data into table rows.
   * @param {object} options - Fetch options (append to list, force refresh)
   * @returns {Promise<object>} The raw data from the server
   */
  async fetchAndSetLogs({ append = false, force = false } = {}) {
    this.isLoading = true;
    try {
      const data = await logsApi.fetchPage(
        getRecentLogs,
        {
          pageSize: this.pageSize,
          search: this.searchValue,
          fromOccurredAtStr: this.fromOccurredAt,
          toOccurredAtStr: this.toOccurredAt,
          lastOccurredAtStr: append ? this.lastOccurredAt : null,
          lastId: append ? this.lastId : null,
          correlationId: this.correlationId,
          observationType: this.observationType,
          integrationCode: this.integrationCode
        },
        { force }
      );

      if (data.typeToSeverity) {
        this.typeToSeverity = {
          ...this.typeToSeverity,
          ...data.typeToSeverity
        };
      }
      const rawRecords = data.records || [];
      const transformedRecords = rawRecords.map((row) =>
        logsApi.transformRow(row, this.typeToSeverity)
      );

      if (append) {
        this.rows = [...this.rows, ...transformedRecords];
      } else {
        this.rows = transformedRecords;
      }

      this.hasMore = data.hasMore;
      this.lastOccurredAt = data.lastOccurredAt;
      this.lastId = data.lastId;
      this.lastUpdated = new Date().toISOString();
      return data;
    } catch (error) {
      logsApi.showError(
        this,
        "Error loading logs",
        logsApi.resolveErrorMessage(error)
      );
      throw error;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Loads and displays the details of a specific log
   * Used for the row action "View Details" in the log table.
   * @param {string} logId - The ID of the log to load
   */
  async loadAndDisplayDetails(logId) {
    this.isLoading = true;
    try {
      const detailWrapper = await getLogDetail({ logId });
      this.selectedRecord = detailWrapper;
      this.showDetailDrawer = true;
    } catch (error) {
      logsApi.showError(
        this,
        "Error loading log details",
        logsApi.resolveErrorMessage(error)
      );
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Closes the detail drawer and resets the selected record
   */
  handleCloseDetailDrawer() {
    this.showDetailDrawer = false;
    this.selectedRecord = null;
  }

  /**
   * @description Opens the detail drawer for a live event row using local data.
   * @param {object} row - The table row containing event data
   */
  displayLocalDetails(row) {
    this.selectedRecord = logsApi.buildLocalDetailWrapper(row);
    this.showDetailDrawer = true;
  }

  // --- Summary Tab ---
  _activeTab = "summary";

  /**
   * @description Gets the currently active tab
   * Used for the tabset navigation.
   * @returns {string} The active tab name
   */
  get activeTab() {
    return this._activeTab;
  }

  /**
   * @description Sets the active tab and updates the tabset
   * @param {string} value - The name of the tab to activate
   */
  set activeTab(value) {
    this._activeTab = value;
    this.updateTabset();
  }

  get summariesData() {
    if (!this.summaries) return null;
    return this.summaries.map((s) => ({
      ...s,
      uniqueKey: `${s.integrationCode}-${this.summaryVersion}`
    }));
  }

  get summariesError() {
    return this._summariesError;
  }

  set summariesError(value) {
    this._summariesError = value;
  }

  get initialLoadDone() {
    return (
      (this.summaries !== undefined && this.summaries !== null) ||
      this.summariesError
    );
  }

  get summaryCardKey() {
    return `summary-${this.summaryVersion}-${this.lastUpdated || 0}`;
  }

  /**
   * @description Filters activePlugins for the Summary tab.
   * Excludes plugins explicitly scoped to 'integrations' only.
   * Plugins with cardLocation 'summary', 'both', or undefined are included.
   * @returns {Array} Summary-tab plugin list
   */
  @api
  get summaryPlugins() {
    if (!this.activePlugins || !this.activePlugins.length) return [];
    return this.activePlugins.filter((p) => p.cardLocation !== "integrations");
  }

  /**
   * @description Filters activePlugins for the Integrations tab.
   * Excludes plugins explicitly scoped to 'summary' only.
   * Plugins with cardLocation 'integrations', 'both', or undefined are included.
   * @returns {Array} Integrations-tab plugin list
   */
  @api
  get integrationPlugins() {
    if (!this.activePlugins || !this.activePlugins.length) return [];
    return this.activePlugins.filter((p) => p.cardLocation !== "summary");
  }

  get globalStats() {
    return logsApi.calculateGlobalStats(this.summariesData);
  }

  /**
   * @description Gets the system pulse stats
   * @returns {Array} An array of objects containing the stats
   */
  get systemPulseStats() {
    const stats = this.globalStats;
    return [
      {
        id: "total",
        label: "Total Events",
        value: stats.total,
        isDateTime: false,
        badgeTheme: null
      },
      {
        id: "success",
        label: "Successful",
        value: stats.success,
        isDateTime: false,
        badgeTheme: "success"
      },
      {
        id: "errors",
        label: "Errors",
        value: stats.errors,
        isDateTime: false,
        badgeTheme: "error"
      }
    ];
  }

  get liveStatusIcon() {
    if (!this.isLiveConnected) return "utility:offline";
    return this.isLiveStale ? "utility:clock" : "utility:connected_apps";
  }

  get liveStatusTooltip() {
    if (!this.isLiveConnected) return "Offline: Not receiving real-time events";
    return this.isLiveStale
      ? "Stale: Connection is old or inactive. Refresh for full sync."
      : "Live: Connected to real-time events";
  }

  get liveStatusClass() {
    if (!this.isLiveConnected) return "slds-icon-text-error";
    return this.isLiveStale
      ? "slds-icon-text-warning"
      : "slds-icon-text-success";
  }

  get liveStatusBadgeClass() {
    if (!this.isLiveConnected)
      return "live-status-badge live-status-badge--disconnected";
    return this.isLiveStale
      ? "live-status-badge live-status-badge--stale"
      : "live-status-badge live-status-badge--connected";
  }

  get liveStatusDotClass() {
    if (!this.isLiveConnected)
      return "live-status-dot live-status-dot--disconnected";
    return this.isLiveStale
      ? "live-status-dot live-status-dot--stale"
      : "live-status-dot live-status-dot--connected";
  }

  get liveStatusText() {
    if (!this.isLiveConnected) return "Offline";
    return this.isLiveStale ? "Stale" : "Live";
  }

  get liveStatusClassWithIndicator() {
    return `${this.liveStatusClass} live-status-indicator`;
  }

  handleTabSelect(event) {
    this._activeTab = event.detail.value;
  }

  updateTabset() {
    const tabset = this.template.querySelector("lightning-tabset");
    if (tabset) {
      tabset.activeTabValue = this._activeTab;
    }
  }

  handleSummaryCardClick() {
    this.activeTab = "filters";
    this.searchValue = "";
    this.loadInitialData();
  }

  /**
   * @description Handles click on a top error integration row.
   * Switches to the Filters tab with the integration code pre-filled.
   * @param {CustomEvent} event - Event with integrationCode in detail
   */
  handleTopErrorClick(event) {
    const code = event.detail?.integrationCode;
    if (code) {
      this.integrationCode = code;
      this.searchValue = "";
      this.loadInitialData();
      this.activeTab = "filters";
    }
  }

  /**
   * @description Handles click on a severity legend item.
   * Switches to the Filters tab for manual filtering.
   * @param {CustomEvent} event - Event with severity in detail
   */
  handleSeverityClick(event) {
    const severity = event.detail?.severity;
    if (severity) {
      this.activeTab = "filters";
    }
  }

  /**
   * @description Handles click events from plugin card components.
   * Routes to the Filters tab with relevant context (integrationCode, severity, etc.).
   * @param {CustomEvent} event - Event with plugin context in detail
   */
  handlePluginClick(event) {
    const detail = event.detail || {};
    if (detail.integrationCode) {
      this.integrationCode = detail.integrationCode;
      this.searchValue = "";
    } else if (detail.severity) {
      this.searchValue = "";
    }
    this.loadInitialData();
    this.activeTab = "filters";
  }

  handleIntegrationCardClick(event) {
    const detail = event.detail || {};
    const normalizedContext = detail.normalizedContext;
    const groupName = detail.groupName;
    const fallbackTerm = detail.displayName || detail.integrationCode || "";

    this.searchValue = groupName || normalizedContext || fallbackTerm;
    this.integrationCode = "";

    this.loadInitialData();
    this.activeTab = "filters";
  }

  get groupedButtonVariant() {
    return this.expandByAttributes ? "neutral" : "brand";
  }

  get detailedButtonVariant() {
    return this.expandByAttributes ? "brand" : "neutral";
  }

  handleViewModeChange(event) {
    const mode = event.currentTarget.dataset.mode;
    this.expandByAttributes = mode === "detailed";
    this.fetchSummariesImperative();
  }

  // --- Keyboard Navigation ---

  @track focusedCardIndex = -1;
  @track showKeyboardGuide = false;

  /**
   * @description Global keyboard shortcut configuration.
   * @type {Object}
   */
  get keyboardShortcuts() {
    return {
      navigateDown: ["j", "ArrowDown"],
      navigateUp: ["k", "ArrowUp"],
      activate: ["Enter", " "],
      escape: ["Escape"],
      showHelp: ["?"],
      switchTab: {
        1: "summary",
        2: "integrations",
        3: "filters",
        4: "admin"
      },
      focusSearch: ["/", "k"]
    };
  }

  /**
   * @description Returns the list of card elements for keyboard navigation.
   * @returns {Element[]} Array of card elements
   */
  get cardElements() {
    const cards = [];
    // Summary tab cards
    const statsCard = this.template.querySelector("c-ihd-stats-card");
    if (statsCard) cards.push(statsCard);
    // Integration summary cards
    const summaryCards = this.template.querySelectorAll(
      "c-ihd-integration-summary-card"
    );
    summaryCards.forEach((card) => cards.push(card));
    return cards;
  }

  /**
   * @description Global keyboard handler for dashboard-level shortcuts.
   * Ignores events from input fields to prevent interference.
   * @param {KeyboardEvent} event - The keydown event
   */
  handleGlobalKeyDown(event) {
    // Ignore if focus is in an input field
    const targetTag = event.target.tagName?.toUpperCase();
    if (["INPUT", "TEXTAREA", "SELECT"].includes(targetTag)) {
      return;
    }
    if (event.target.getAttribute("contenteditable") === "true") {
      return;
    }

    const key = event.key;
    const shortcuts = this.keyboardShortcuts;

    // Tab switching (1-4)
    if (shortcuts.switchTab[key]) {
      event.preventDefault();
      this.activeTab = shortcuts.switchTab[key];
      return;
    }

    // Search focus (/ or k)
    if (shortcuts.focusSearch.includes(key) && event.key !== "k") {
      event.preventDefault();
      this.focusSearchInput();
      return;
    }

    // Refresh (r)
    if (key === "r" && !event.ctrlKey && !event.metaKey) {
      event.preventDefault();
      this.refreshAll();
      return;
    }

    // Escape - close drawer or keyboard guide
    if (shortcuts.escape.includes(key)) {
      event.preventDefault();
      if (this.showKeyboardGuide) {
        this.showKeyboardGuide = false;
      } else if (this.showDetailDrawer) {
        this.handleCloseDetailDrawer();
      }
      return;
    }

    // Keyboard guide (?)
    if (shortcuts.showHelp.includes(key)) {
      event.preventDefault();
      this.showKeyboardGuide = true;
      return;
    }

    // Card navigation (j/k or arrow keys)
    const cards = this.cardElements;
    if (cards.length === 0) return;

    if (shortcuts.navigateDown.includes(key)) {
      event.preventDefault();
      this.focusedCardIndex = Math.min(
        this.focusedCardIndex + 1,
        cards.length - 1
      );
      this.updateCardFocus();
      return;
    }

    if (shortcuts.navigateUp.includes(key)) {
      event.preventDefault();
      this.focusedCardIndex = Math.max(this.focusedCardIndex - 1, 0);
      this.updateCardFocus();
      return;
    }

    // Activate focused card (Enter or Space)
    if (shortcuts.activate.includes(key)) {
      if (this.focusedCardIndex >= 0 && this.focusedCardIndex < cards.length) {
        event.preventDefault();
        this.activateFocusedCard();
      }
    }
  }

  /**
   * @description Updates the visual focus state on cards.
   */
  updateCardFocus() {
    const cards = this.cardElements;
    cards.forEach((card, index) => {
      if (card.classList) {
        if (index === this.focusedCardIndex) {
          card.classList.add("card-focused");
        } else {
          card.classList.remove("card-focused");
        }
      }
    });
  }

  /**
   * @description Activates the currently focused card by simulating a click.
   */
  activateFocusedCard() {
    const cards = this.cardElements;
    if (this.focusedCardIndex >= 0 && this.focusedCardIndex < cards.length) {
      const card = cards[this.focusedCardIndex];
      // Dispatch a click event on the card
      card.click();
    }
  }

  /**
   * @description Focuses the search input field in the filters component.
   */
  focusSearchInput() {
    const filters = this.template.querySelector("c-ihd-filters");
    if (filters) {
      const searchInput = filters.template.querySelector("lightning-input");
      if (searchInput) {
        searchInput.focus();
      }
    }
  }

  /**
   * @description Closes the keyboard shortcuts guide modal.
   */
  handleKeyboardGuideClose() {
    this.showKeyboardGuide = false;
  }
}
