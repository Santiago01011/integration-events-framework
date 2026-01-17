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

/**
 * @description Base columns for the logs datatable.
 */
const BASE_COLUMNS = [
  {
    label: "Occurred At",
    fieldName: "OccurredAt__c",
    type: "date",
    typeAttributes: {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit"
    },
    fixedWidth: 200
  },
  {
    label: "Status",
    fieldName: "",
    type: "text",
    fixedWidth: 80,
    cellAttributes: {
      iconName: { fieldName: "statusIconName" },
      iconPosition: "left",
      alignment: "center"
    }
  },
  { label: "Integration", fieldName: "IntegrationCode__c", type: "text" },
  {
    label: "Context",
    fieldName: "contextPreview",
    type: "text",
    wrapText: true,
    cellAttributes: { title: { fieldName: "Normalized_Context__c" } }
  },
  {
    label: "Correlation",
    fieldName: "CorrelationId__c",
    type: "text",
    wrapText: true
  }
];

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

  @track rows = [];

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
      ...BASE_COLUMNS,
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
  @track lastUpdated;
  @track summaries;

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
    logsApi.initRealtime(this, (payload) => this.handleNewEvent(payload));
  }

  disconnectedCallback() {
    logsApi.unsubscribeFromLogs(this);
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
   * @description Handles the 'rowaction' event from c-ihd-table
   */
  async handleRowAction(event) {
    const action = event.detail.action;
    const row = event.detail.row;

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
   * @description Handles the 'loadmore' event from c-ihd-table
   */
  async handleLoadMoreData() {
    if (!this.hasMore || this.isLoading) {
      return;
    }
    this.isLoading = true;
    const lastRecord =
      this.rows.length > 0 ? this.rows[this.rows.length - 1] : null;

    try {
      const data = await logsApi.fetchPage(
        getRecentLogs,
        {
          pageSize: this.pageSize,
          search: this.searchValue,
          fromOccurredAtStr: this.fromOccurredAt,
          toOccurredAtStr: this.toOccurredAt,
          lastKey: {
            lastOccurred: lastRecord?.OccurredAt__c,
            lastId: lastRecord?.Id
          },
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
      const newLogs = (data.records || []).map((row) => this.transformRow(row));
      this.rows = [...this.rows, ...newLogs];
      this.hasMore = data.hasMore;
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
   */
  async fetchAndSetLogs({ append = false, force = false } = {}) {
    this.isLoading = true;
    try {
      const lastRecord =
        append && this.rows.length ? this.rows[this.rows.length - 1] : null;

      const data = await logsApi.fetchPage(
        getRecentLogs,
        {
          pageSize: this.pageSize,
          search: this.searchValue,
          fromOccurredAtStr: this.fromOccurredAt,
          toOccurredAtStr: this.toOccurredAt,
          lastKey: lastRecord
            ? {
                lastOccurred: lastRecord.OccurredAt__c,
                lastId: lastRecord.Id
              }
            : null,
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
        this.transformRow(row)
      );

      if (append) {
        this.rows = [...this.rows, ...transformedRecords];
      } else {
        this.rows = transformedRecords;
      }

      this.hasMore = data.hasMore;
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
   * @description Helper to format a raw record for the table
   */
  transformRow(record) {
    const type = (record.ObservationType__c || "").toUpperCase();
    const severity = this.typeToSeverity[type];

    let iconName = "utility:help";

    if (severity === "ERROR" || severity === "FATAL") {
      iconName = "utility:error";
    } else if (severity === "WARN") {
      iconName = "utility:warning";
    } else if (severity === "SUCCESS") {
      iconName = "utility:success";
    } else if (severity === "INFO") {
      iconName = "utility:info";
    }

    return {
      ...record,
      contextPreview: record.Normalized_Context__c,
      statusIconName: iconName
    };
  }

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

  handleCloseDetailDrawer() {
    this.showDetailDrawer = false;
    this.selectedRecord = null;
  }

  // --- EMP / Event Monitoring Logic ---

  handleNewEvent(payload) {
    logsApi.showToast(
      this,
      "New Event",
      `${payload.Context__c || "Integration Activity"}`,
      "info"
    );
    logsApi.invalidateForRecord(payload);
    this.refreshAll();
  }

  _activeTab = "summary";

  get activeTab() {
    return this._activeTab;
  }
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
    const data = this.summariesData || [];
    let total = 0;
    let errors = 0;
    let success = 0;

    data.forEach((item) => {
      total += item.totalEvents || 0;
      errors += item.errorCount || 0;
      success += item.successCount || 0;
    });

    const successRate = total > 0 ? Math.round((success / total) * 100) : 100;
    const errorRate = 100 - successRate;

    return {
      total,
      errors,
      success,
      successRate,
      errorRate,
      successRateLabel: "Success",
      errorRateLabel: "Errors",
      progressStyle: `background: linear-gradient(90deg, #04844b ${successRate}%, #c23934 ${successRate}%); width: 100%;`
    };
  }

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
