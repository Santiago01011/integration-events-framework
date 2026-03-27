import { LightningElement, api, track } from "lwc";

const DAY_HEADERS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];

/**
 * @description Calendar grid component that renders month/week views.
 * Uses CSS Grid for layout and emits dayclick events.
 */
export default class CalendarGrid extends LightningElement {
  /** @type {string} Current view: 'month' or 'week' */
  @api currentView = "month";

  /** @type {string} Navigation date for current period */
  @api navigationDate;

  /**
   * @description Gets navigation date as a Date object.
   * Handles both string and Date object inputs.
   * @returns {Date}
   * @private
   */
  get _navigationDateObj() {
    if (!this.navigationDate) return new Date();
    if (this.navigationDate instanceof Date) return this.navigationDate;
    if (typeof this.navigationDate === "string") {
      // Parse ISO string to local date
      const [year, month, day] = this.navigationDate.split(/[-T]/);
      return new Date(
        parseInt(year, 10),
        parseInt(month, 10) - 1,
        parseInt(day, 10) || 1
      );
    }
    return new Date(this.navigationDate);
  }

  /** @type {string} Selected date string (YYYY-MM-DD) */
  @api selectedDate;

  /**
   * @description Gets the selected date as a formatted string for comparison.
   * Handles both string and Date object inputs.
   * @returns {string|null}
   * @private
   */
  get _selectedDateStr() {
    if (!this.selectedDate) return null;
    if (typeof this.selectedDate === "string") return this.selectedDate;
    if (this.selectedDate instanceof Date)
      return this._formatDate(this.selectedDate);
    // Handle case where it might be serialized as ISO string
    try {
      const date = new Date(this.selectedDate);
      return this._formatDate(date);
    } catch {
      return null;
    }
  }

  /** @type {Object} Internal storage for dailyCountsMap - tracked for reactivity */
  @track _dailyCountsMap = {};

  /**
   * @description Daily counts map keyed by 'YYYY-MM-DD'.
   * Uses getter/setter to ensure proper reactivity when passed from parent.
   * @type {Object}
   */
  @api
  get dailyCountsMap() {
    return this._dailyCountsMap;
  }
  set dailyCountsMap(value) {
    console.log(
      "calendarGrid setter received:",
      typeof value,
      value ? Object.keys(value) : "null"
    );
    this._dailyCountsMap = value || {};
  }

  /** @type {string[]} Day headers for the grid */
  get dayHeaders() {
    return DAY_HEADERS;
  }

  /**
   * @description Gets the week objects for the calendar grid.
   * Each week contains an array of day objects with date, counts, and metadata.
   * @returns {Array}
   */
  get calendarWeeks() {
    console.log(
      "calendarWeeks getter called, _dailyCountsMap:",
      this._dailyCountsMap
    );
    const weeks = [];
    const navDate = this._navigationDateObj;
    const year = navDate.getFullYear();
    const month = navDate.getMonth();

    if (this.currentView === "month") {
      // Calculate first day of month and calendar start
      const firstOfMonth = new Date(year, month, 1);
      const startDate = new Date(firstOfMonth);
      startDate.setDate(startDate.getDate() - firstOfMonth.getDay()); // Go back to Sunday

      // Generate6 weeks (max needed for month view)
      let currentDate = new Date(startDate);
      for (let weekNum = 0; weekNum < 6; weekNum++) {
        const days = [];
        for (let dayNum = 0; dayNum < 7; dayNum++) {
          const dateStr = this._formatDate(currentDate);
          console.log("Looking up:", dateStr, "in", this._dailyCountsMap);
          const counts = this.dailyCountsMap[dateStr] || {
            totalCount: 0,
            successCount: 0,
            warningCount: 0,
            errorCount: 0,
            infoCount: 0
          };

          days.push({
            key: dateStr,
            date: dateStr,
            dayNumber: currentDate.getDate(),
            isCurrentMonth: currentDate.getMonth() === month,
            isToday: this._isToday(currentDate),
            isSelected: dateStr === this._selectedDateStr,
            counts: counts,
            severity: this._getSeverity(counts)
          });

          currentDate.setDate(currentDate.getDate() + 1);
        }
        weeks.push({ key: `week-${weekNum}`, days });
      }
    } else {
      // Week view: show only one week containing the navigation date
      const dayOfWeek = navDate.getDay();
      const startDate = new Date(navDate);
      startDate.setDate(startDate.getDate() - dayOfWeek);

      const days = [];
      let currentDate = new Date(startDate);
      for (let dayNum = 0; dayNum < 7; dayNum++) {
        const dateStr = this._formatDate(currentDate);
        const counts = this.dailyCountsMap[dateStr] || {
          totalCount: 0,
          successCount: 0,
          warningCount: 0,
          errorCount: 0,
          infoCount: 0
        };

        days.push({
          key: dateStr,
          date: dateStr,
          dayNumber: currentDate.getDate(),
          isCurrentMonth: true,
          isToday: this._isToday(currentDate),
          isSelected: dateStr === this._selectedDateStr,
          counts: counts,
          severity: this._getSeverity(counts)
        });

        currentDate.setDate(currentDate.getDate() + 1);
      }
      weeks.push({ key: "week-0", days });
    }

    return weeks;
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
   * @description Checks if a date is today.
   * @param {Date} date
   * @returns {boolean}
   * @private
   */
  _isToday(date) {
    const today = new Date();
    return (
      date.getFullYear() === today.getFullYear() &&
      date.getMonth() === today.getMonth() &&
      date.getDate() === today.getDate()
    );
  }

  /**
   * @description Determines the severity level for a day based on counts.
   * @param {Object} counts
   * @returns {string} 'error', 'warning', 'success', or 'info'
   * @private
   */
  _getSeverity(counts) {
    if (counts.errorCount > 0) return "error";
    if (counts.warningCount > 0) return "warning";
    if (counts.successCount > 0) return "success";
    if (counts.infoCount > 0) return "info";
    return "none";
  }

  /**
   * @description Handles day click event from day-cell.
   * @param {CustomEvent} event
   */
  handleDayClick(event) {
    this.dispatchEvent(
      new CustomEvent("dayclick", {
        detail: { date: event.detail.date }
      })
    );
  }
}
