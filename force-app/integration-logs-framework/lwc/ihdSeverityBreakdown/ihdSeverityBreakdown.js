import { LightningElement, api } from "lwc";

const SEVERITY_COLOR_MAP = {
  SUCCESS: "var(--slds-g-color-success-base-50, #2e844a)",
  WARN: "var(--slds-g-color-warning-base-50, #c96512)",
  ERROR: "var(--slds-g-color-error-base-50, #c23934)",
  FATAL: "var(--slds-g-color-error-base-50, #c23934)",
  INFO: "var(--slds-g-color-brand-base-50, #0176d3)"
};

const SEVERITY_LABELS = {
  SUCCESS: "Success",
  WARN: "Warning",
  ERROR: "Error",
  FATAL: "Fatal",
  INFO: "Info"
};

/**
 * @description Renders a conic-gradient donut chart showing severity distribution
 * with a color-coded legend displaying counts and percentages.
 */
export default class IhdSeverityBreakdown extends LightningElement {
  /**
   * @description Array of severity count entries from getSeverityCounts().
   * Each entry: { severity: string, count: number, percentage: number }
   * @type {Array<{severity: string, count: number, percentage: number}>}
   */
  @api severityCounts = [];

  /**
   * @description Whether the component is in a loading state.
   * @type {boolean}
   */
  @api isLoading = false;

  /**
   * @description Gets the donut background style using conic-gradient.
   * Computes gradient stops from severity percentages.
   * @returns {string} CSS background value
   */
  get donutStyle() {
    if (!this.hasData) return "";
    const segments = [];
    let cumulative = 0;
    for (const entry of this.displayEntries) {
      const end = cumulative + entry.percentage;
      const color =
        SEVERITY_COLOR_MAP[entry.severity] || SEVERITY_COLOR_MAP.INFO;
      segments.push(`${color} ${cumulative}% ${end}%`);
      cumulative = end;
    }
    return `background: conic-gradient(${segments.join(", ")})`;
  }

  /**
   * @description Gets the legend entries with resolved colors and labels.
   * @returns {Array<{severity: string, label: string, count: number, percentage: number, color: string, dotStyle: string}>}
   */
  get legendEntries() {
    return this.displayEntries.map((entry) => ({
      ...entry,
      label: SEVERITY_LABELS[entry.severity] || entry.severity,
      color: SEVERITY_COLOR_MAP[entry.severity] || SEVERITY_COLOR_MAP.INFO,
      dotStyle: `background-color: ${SEVERITY_COLOR_MAP[entry.severity] || SEVERITY_COLOR_MAP.INFO}`
    }));
  }

  /**
   * @description Whether there is data to display (any count > 0).
   * @returns {boolean}
   */
  get hasData() {
    return this.displayEntries.some((entry) => entry.count > 0);
  }

  /**
   * @description Gets the entries to display, filtered to known severities.
   * FATAL is merged into ERROR color but shown separately if present.
   * @returns {Array}
   */
  get displayEntries() {
    if (!this.severityCounts || this.severityCounts.length === 0) return [];
    return this.severityCounts.filter(
      (entry) => entry.severity && entry.count !== undefined
    );
  }

  /**
   * @description Handles click on a severity legend item.
   * Dispatches severityclick event with severity level.
   * @param {Event} event - Click event from a legend item
   */
  handleLegendClick(event) {
    const severity = event.currentTarget.dataset.severity;
    if (severity) {
      this.dispatchEvent(
        new CustomEvent("severityclick", {
          detail: { severity }
        })
      );
    }
  }

  /**
   * @description Handles keyboard activation on a legend item for accessibility.
   * @param {KeyboardEvent} event - Keydown event
   */
  handleKeyDown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.handleLegendClick(event);
    }
  }
}
