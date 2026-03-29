import { LightningElement, api, track, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import IEF_PLUGIN_ACTIONS from "@salesforce/messageChannel/IEF_Plugin_Actions__c";
import getDailyLogCounts from "@salesforce/apex/CalendarController.getDailyLogCounts";
import getIntegrationBreakdown from "@salesforce/apex/CalendarController.getIntegrationBreakdown";
import logsApi from "c/utilsLogsApi";

/**
 * @description Card implementation for the Calendar plugin.
 * Receives PluginContext from dashboard and fetches daily log counts with filters.
 * This component is dynamically rendered via lwc:is — never static-imported by core.
 *
 * PluginContext contract:
 * {
 *   pluginName: string,
 *   filters: {
 *     search?: string,
 *     observationType?: string,
 *     integrationCode?: string,
 *     correlationId?: string,
 *     fromOccurredAt?: string | null,
 *     to_occurredAt?: string | null
 *   },
 *   location: 'dashboard' | 'record' | 'app',
 *   refreshToken: string,
 *   capabilities: { canExport: boolean, canFilter: boolean, canRefresh: boolean }
 * }
 */
export default class CalendarCardImpl extends LightningElement {
  /** @type {string} Internal storage for contextData */
  _contextData = "";

  /** @type {Object} LMS message context for publishing actions */
  @wire(MessageContext)
  messageContext;

  /** @type {Object} Parsed PluginContext */
  parsedContext = null;

  /** @type {boolean} Whether data is loading */
  isLoading = true;

  /** @type {boolean} Whether an error occurred */
  hasError = false;

  /** @type {string} Error message */
  errorMessage = "";

  /** @type {Object} Daily counts map keyed by 'YYYY-MM-DD' */
  @track dailyCountsMap = {};

  /** @type {Object} Integration breakdown keyed by 'YYYY-MM-DD' */
  @track integrationBreakdownMap = {};

  /** @type {string} Current view: 'month' or 'week' */
  currentView = "month";

  /** @type {Date|null} Selected date for drill-down */
  selectedDate = null;

  /** @type {Date} Navigation date for current displayed period */
  navigationDate = new Date();

  /** @type {Object} Cache keyed by filter signature */
  _cache = {};

  connectedCallback() {
    this._parseAndFetch();
  }

  disconnectedCallback() {
    this._cache = null;
  }

  /**
   * @description Setter for contextData — re-fetches when context changes.
   * Dashboard updates contextData when filters change.
   */
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

  /**
   * @description Parses context and fetches data with filters.
   * @private
   */
  _parseAndFetch() {
    this._parseContextData();
    if (!this.hasError) {
      this._fetchData();
    }
  }

  /**
   * @description Parses the contextData JSON string safely.
   * @private
   */
  _parseContextData() {
    this.hasError = false;
    this.errorMessage = "";

    if (!this.contextData || this.contextData === "") {
      this.parsedContext = { filters: {} };
      return;
    }

    try {
      this.parsedContext = JSON.parse(this.contextData);
      if (!this.parsedContext.filters) {
        this.parsedContext.filters = {};
      }
    } catch {
      this.hasError = true;
      this.errorMessage = "Invalid context data received";
      this.parsedContext = { filters: {} };
    }
  }

  /**
   * @description Generates a cache key from filters and date range.
   * @returns {string}
   * @private
   */
  _getCacheKey() {
    const filters = this.parsedContext?.filters || {};
    const dateRange = this._getDateRange();
    return JSON.stringify({
      ...filters,
      month: `${dateRange.start}_${dateRange.end}`
    });
  }

  /**
   * @description Gets the date range for the current navigation period.
   * @returns {{start: string, end: string}}
   * @private
   */
  _getDateRange() {
    const year = this.navigationDate.getFullYear();
    const month = this.navigationDate.getMonth();

    if (this.currentView === "month") {
      // Get first and last day of month
      const start = new Date(year, month, 1);
      const end = new Date(year, month + 1, 0);
      return {
        start: this._formatDate(start),
        end: this._formatDate(end)
      };
    }
    // Week view: get start and end of week containing navigation date
    const dayOfWeek = this.navigationDate.getDay();
    const start = new Date(this.navigationDate);
    start.setDate(start.getDate() - dayOfWeek);
    const end = new Date(start);
    end.setDate(end.getDate() + 6);
    return {
      start: this._formatDate(start),
      end: this._formatDate(end)
    };
  }

  /**
   * @description Formats a date as YYYY-MM-DD.
   * @param {Date} date
   * @returns {string}
   * @private
   */
  _formatDate(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  /**
   * @description Parses a date string (YYYY-MM-DD) as local date, avoiding UTC offset bug.
   * JavaScript's new Date("YYYY-MM-DD") parses as UTC midnight, which causes a -1 day
   * offset in timezones west of UTC when using local timezone methods.
   * @param {string} dateStr - Date string in YYYY-MM-DD format
   * @returns {Date} Date object in local timezone
   * @private
   */
  _parseLocalDate(dateStr) {
    const [year, month, day] = dateStr.split("-");
    return new Date(
      parseInt(year, 10),
      parseInt(month, 10) - 1,
      parseInt(day, 10)
    );
  }

  /**
   * @description Fetches daily log counts from Apex with filters.
   * @private
   */
  async _fetchData() {
    this.isLoading = true;
    this.hasError = false;

    const cacheKey = this._getCacheKey();

    // Check cache first
    if (this._cache[cacheKey]) {
      this.dailyCountsMap = { ...this._cache[cacheKey] };
      this.isLoading = false;
      return;
    }

    try {
      const filters = this.parsedContext?.filters || {};
      const dateRange = this._getDateRange();

      const result = await getDailyLogCounts({
        search: filters.search || null,
        observationType: filters.observationType || null,
        integrationCode: filters.integrationCode || null,
        correlationId: filters.correlationId || null,
        fromOccurredAt: dateRange.start,
        toOccurredAt: dateRange.end
      });

      // Transform array to map keyed by date string
      const countsMap = {};
      if (result && Array.isArray(result)) {
        for (const item of result) {
          const dateKey = item.logDate; // Apex returns Date as YYYY-MM-DD string
          countsMap[dateKey] = {
            totalCount: item.totalCount || 0,
            successCount: item.successCount || 0,
            warningCount: item.warningCount || 0,
            errorCount: item.errorCount || 0,
            infoCount: item.infoCount || 0
          };
        }
      }

      this.dailyCountsMap = { ...countsMap };
      this._cache[cacheKey] = { ...countsMap };

      // Fetch integration breakdown for popovers
      try {
        const intResult = await getIntegrationBreakdown({
          search: filters.search || null,
          observationType: filters.observationType || null,
          integrationCode: filters.integrationCode || null,
          correlationId: filters.correlationId || null,
          fromOccurredAt: dateRange.start,
          toOccurredAt: dateRange.end
        });

        console.log("[Calendar] Integration breakdown result:", intResult);

        // Transform integration results to map keyed by date
        const intMap = {};
        if (intResult) {
          for (const [dateKey, intList] of Object.entries(intResult)) {
            if (Array.isArray(intList)) {
              intMap[dateKey] = intList.map((item) => ({
                integrationCode: item.integrationCode,
                errorCount: item.errorCount || 0,
                warningCount: item.warningCount || 0,
                successCount: item.successCount || 0,
                infoCount: item.infoCount || 0
              }));
              console.log(
                "[Calendar] Date",
                dateKey,
                "integrations:",
                intMap[dateKey]
              );
            }
          }
        }
        this.integrationBreakdownMap = { ...intMap };
        console.log(
          "[Calendar] Final integrationBreakdownMap:",
          this.integrationBreakdownMap
        );
      } catch (intError) {
        console.error(
          "[Calendar] Error fetching integration breakdown:",
          intError
        );
      }
    } catch (error) {
      this.hasError = true;
      this.errorMessage = logsApi.resolveErrorMessage(error);
      this.dailyCountsMap = {};
      logsApi.showError(this, "Error loading calendar data", this.errorMessage);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * @description Whether the parsed context is valid.
   * @returns {boolean}
   */
  @api
  get hasValidContext() {
    return this.parsedContext !== null && !this.hasError;
  }

  /**
   * @description Plugin label for display.
   * @returns {string}
   */
  get cardTitle() {
    return "Calendar View";
  }

  /**
   * @description Current month and year display string.
   * @returns {string}
   */
  get currentMonthYear() {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return `${months[this.navigationDate.getMonth()]} ${this.navigationDate.getFullYear()}`;
  }

  /**
   * @description Variant for month view button.
   * @returns {string}
   */
  get monthViewVariant() {
    return this.currentView === "month" ? "brand" : "neutral";
  }

  /**
   * @description Variant for week view button.
   * @returns {string}
   */
  get weekViewVariant() {
    return this.currentView === "week" ? "brand" : "neutral";
  }

  /**
   * @description Handles previous button click.
   */
  handlePrevious() {
    const newDate = new Date(this.navigationDate);
    if (this.currentView === "month") {
      newDate.setMonth(newDate.getMonth() - 1);
    } else {
      newDate.setDate(newDate.getDate() - 7);
    }
    this.navigationDate = newDate;
    this._fetchData();
  }

  /**
   * @description Handles next button click.
   */
  handleNext() {
    const newDate = new Date(this.navigationDate);
    if (this.currentView === "month") {
      newDate.setMonth(newDate.getMonth() + 1);
    } else {
      newDate.setDate(newDate.getDate() + 7);
    }
    this.navigationDate = newDate;
    this._fetchData();
  }

  /**
   * @description Handles today button click.
   */
  handleToday() {
    this.navigationDate = new Date();
    this._fetchData();
  }

  /**
   * @description Handles month view button click.
   */
  handleMonthView() {
    this.currentView = "month";
    this._fetchData();
  }

  /**
   * @description Handles week view button click.
   */
  handleWeekView() {
    this.currentView = "week";
    this._fetchData();
  }

  /**
   * @description Handles day cell click.
   * Publishes to IEF_Plugin_Actions LMS channel to navigate to Filters tab.
   * Converts date-only strings to UTC ISO format for API compatibility.
   * @param {CustomEvent} event
   */
  handleDayClick(event) {
    const dateStr = event.detail.date;
    this.selectedDate = this._parseLocalDate(dateStr);

    // Convert date-only to UTC ISO strings for start of day and end of day
    const fromUtc = this._dateToUtcIso(dateStr, "00:00:00");
    const toUtc = this._dateToUtcIso(dateStr, "23:59:59");

    publish(this.messageContext, IEF_PLUGIN_ACTIONS, {
      pluginName: "Calendar_Card",
      action: "navigate_to_filters",
      payload: {
        fromDate: fromUtc,
        toDate: toUtc
      }
    });
  }

  /**
   * @description Converts a date-only string (YYYY-MM-DD) to UTC ISO format.
   * Treats the time as local timezone, then converts to UTC.
   * @param {string} dateStr - Date string in YYYY-MM-DD format
   * @param {string} time - Time string in HH:MM:SS format
   * @returns {string} UTC ISO string
   * @private
   */
  _dateToUtcIso(dateStr, time = "00:00:00") {
    if (!dateStr) return "";
    const [year, month, day] = dateStr.split("-").map(Number);
    const [hour, minute, second] = time.split(":").map(Number);
    const local = new Date(year, month - 1, day, hour, minute, second);
    return isNaN(local.getTime()) ? "" : local.toISOString();
  }
}
