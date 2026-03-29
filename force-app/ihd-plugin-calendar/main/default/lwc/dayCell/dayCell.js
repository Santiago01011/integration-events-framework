import { LightningElement, api, track } from "lwc";

/**
 * @description Individual day cell component for the calendar grid.
 * Shows day number, severity indicators, and background color based on severity.
 */
export default class DayCell extends LightningElement {
  /** @type {Object} Internal storage for dayData - tracked for reactivity */
  @track _dayData = {};

  /**
   * @description Day data with date, counts, and metadata.
   * Uses getter/setter to ensure proper reactivity when passed from parent.
   * @type {Object}
   */
  @api
  get dayData() {
    return this._dayData;
  }
  set dayData(value) {
    this._dayData = value || {};
  }

  /**
   * @description Computed CSS class for the cell based on state.
   * @returns {string}
   */
  get cellClass() {
    const classes = ["day-cell"];

    if (!this.dayData) {
      return classes.join(" ");
    }

    // Add state classes
    if (!this.dayData.isCurrentMonth) {
      classes.push("outside-month");
    }
    if (this.dayData.isToday) {
      classes.push("today");
    }
    if (this.dayData.isSelected) {
      classes.push("selected");
    }

    // Add severity class
    if (this.dayData.severity && this.dayData.severity !== "none") {
      classes.push(`severity-${this.dayData.severity}`);
    }

    return classes.join(" ");
  }

  /**
   * @description Whether the day has any log data.
   * @returns {boolean}
   */
  get hasData() {
    return (
      this.dayData && this.dayData.counts && this.dayData.counts.totalCount > 0
    );
  }

  /**
   * @description Accessible label for the day cell.
   * @returns {string}
   */
  get ariaLabel() {
    if (!this.dayData) return "";

    const dateStr = this.dayData.date;
    const counts = this.dayData.counts || {};

    if (counts.totalCount === 0) {
      return `${dateStr}, no logs`;
    }

    const parts = [];
    if (counts.errorCount) parts.push(`${counts.errorCount} errors`);
    if (counts.warningCount) parts.push(`${counts.warningCount} warnings`);
    if (counts.successCount) parts.push(`${counts.successCount} successes`);
    if (counts.infoCount) parts.push(`${counts.infoCount} info`);

    return `${dateStr}, ${counts.totalCount} total logs: ${parts.join(", ")}`;
  }

  // ========== Popover Data Getters ==========

  /**
   * @description Gets top integrations for error category.
   * @returns {Array} List of integration codes with error counts
   */
  get errorIntegrations() {
    const intBreakdown = this.dayData?.integrationBreakdown || [];
    return intBreakdown
      .filter((item) => item.errorCount > 0)
      .slice(0, 5)
      .map((item) => `${item.integrationCode}: ${item.errorCount} errors`);
  }

  /**
   * @description Gets top integrations for warning category.
   * @returns {Array} List of integration codes with warning counts
   */
  get warningIntegrations() {
    const intBreakdown = this.dayData?.integrationBreakdown || [];
    return intBreakdown
      .filter((item) => item.warningCount > 0)
      .slice(0, 5)
      .map((item) => `${item.integrationCode}: ${item.warningCount} warnings`);
  }

  /**
   * @description Gets top integrations for success category.
   * @returns {Array} List of integration codes with success counts
   */
  get successIntegrations() {
    const intBreakdown = this.dayData?.integrationBreakdown || [];
    return intBreakdown
      .filter((item) => item.successCount > 0)
      .slice(0, 5)
      .map((item) => `${item.integrationCode}: ${item.successCount} success`);
  }

  /**
   * @description Gets top integrations for info category.
   * @returns {Array} List of integration codes with info counts
   */
  get infoIntegrations() {
    const intBreakdown = this.dayData?.integrationBreakdown || [];
    return intBreakdown
      .filter((item) => item.infoCount > 0)
      .slice(0, 5)
      .map((item) => `${item.integrationCode}: ${item.infoCount} info`);
  }

  get errorSummary() {
    const c = this.dayData?.counts || {};
    if (!c.errorCount) return null;
    const parts = [];
    if (c.errorCount) parts.push(`${c.errorCount} errors`);
    if (c.warningCount) parts.push(`${c.warningCount} warnings`);
    if (c.successCount) parts.push(`${c.successCount} success`);
    if (c.infoCount) parts.push(`${c.infoCount} info`);
    return parts;
  }

  get errorItems() {
    const c = this.dayData?.counts || {};
    if (!c.errorCount) return [];
    return [c.errorCount + " errors"];
  }

  get successItems() {
    const c = this.dayData?.counts || {};
    if (!c.successCount && !c.warningCount && !c.infoCount && !c.errorCount) {
      return [];
    }
    const items = [];
    if (c.successCount) items.push(`${c.successCount} success logs`);
    if (c.warningCount) items.push(`${c.warningCount} warnings`);
    if (c.infoCount) items.push(`${c.infoCount} info logs`);
    if (c.errorCount) items.push(`${c.errorCount} error logs`);
    return items;
  }

  // ========== Event Handlers ==========

  /**
   * @description Handles click on the day cell.
   */
  handleClick() {
    if (this.dayData) {
      this.dispatchEvent(
        new CustomEvent("dayclick", {
          detail: { date: this.dayData.date }
        })
      );
    }
  }

  /**
   * @description Handles keyboard navigation.
   * @param {KeyboardEvent} event
   */
  handleKeyDown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.handleClick();
    }
  }
}
