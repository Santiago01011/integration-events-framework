import { LightningElement, wire, track } from "lwc";
import getRecentLogs from "@salesforce/apex/IntegrationHealthController.getRecentLogs";
import getLogDetail from "@salesforce/apex/IntegrationHealthController.getLogDetail";
import getIntegrationSummaries from "@salesforce/apex/IntegrationHealthController.getIntegrationSummaries";
import isAdminUser from "@salesforce/apex/IntegrationHealthController.isAdminUser";
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

  get columns() {
    let actions = [{ label: "View Details", name: "view_details" }];

    if (this.isAdmin) {
      actions.push({ label: "Change Status (Type)", name: "change_status" });
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
  @track hasMore = false;

  @track rows = [];
  @track summaries = [];

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
  @track isLiveConnected = false;
  @track isLiveStale = false;

  @wire(isAdminUser)
  wiredIsAdmin({ error, data }) {
    if (data !== undefined) {
      this.isAdmin = data;
    } else if (error) {
      this.isAdmin = false;
    }
  }

  _debouncedRefreshAll;

  connectedCallback() {
    this._debouncedRefreshAll = logsApi.debounce(
      () => this._refreshAllImmediate(),
      REFRESH_DEBOUNCE_MS
    );
    this.loadInitialData();
    this.fetchSummariesImperative();
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
   */
  handleLiveActivity() {
    this.fetchSummariesImperative();
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
   * @description Handles the 'filterschanged' event from c-ihd-filters
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
   * @description Internal refresh implementation - fetches logs and summaries in parallel
   */
  async _refreshAllImmediate() {
    this.isLoading = true;
    try {
      const eventHub = this.template.querySelector("c-ihd-event-hub");
      if (eventHub) {
        eventHub.refresh();
      }

      await Promise.all([
        this.fetchAndSetLogs({ append: false, force: true }),
        this.fetchSummariesImperative()
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
      logsApi.showError(
        this,
        "Error loading summaries",
        logsApi.resolveErrorMessage(error)
      );
    }
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
}
