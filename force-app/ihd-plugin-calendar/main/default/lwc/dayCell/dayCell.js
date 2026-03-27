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
