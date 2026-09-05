import { LightningElement, api } from "lwc";

const TREND_SYMBOLS = {
  up: "▲",
  down: "▼",
  flat: "─"
};

const TREND_TITLES = {
  up: "Trending worse",
  down: "Improving",
  flat: "Stable"
};

/**
 * @description Displays a ranked list of integrations by error count
 * with proportional CSS horizontal bars and trend indicators.
 */
export default class IefTopErrorIntegrations extends LightningElement {
  /**
   * @description Array of top error integration entries from getTopErrorIntegrations().
   * Each entry: { integrationCode, displayName, errorCount, totalEvents, trend }
   * @type {Array<{integrationCode: string, displayName: string, errorCount: number, totalEvents: number, trend: string}>}
   */
  @api integrations = [];

  /**
   * @description Maximum number of integrations to display.
   * @type {number}
   */
  @api topN = 5;

  /**
   * @description Whether the component is in a loading state.
   * @type {boolean}
   */
  @api isLoading = false;

  /**
   * @description Whether there are integrations to display.
   * @returns {boolean}
   */
  get hasData() {
    return this.displayIntegrations.length > 0;
  }

  /**
   * @description Gets the integrations to display, limited to topN.
   * Computes bar width and trend metadata for each row.
   * @returns {Array}
   */
  @api
  get displayIntegrations() {
    if (!this.integrations || this.integrations.length === 0) return [];
    const limited = this.integrations.slice(0, this.topN);
    const maxErrors = Math.max(...limited.map((i) => i.errorCount), 1);
    return limited.map((item, index) => {
      const normalizedTrend =
        item.trend && TREND_SYMBOLS[item.trend] ? item.trend : "flat";
      return {
        ...item,
        rank: index + 1,
        barWidth: `${(item.errorCount / maxErrors) * 100}%`,
        barStyle: `width: ${(item.errorCount / maxErrors) * 100}%`,
        trendSymbol: TREND_SYMBOLS[item.trend] || TREND_SYMBOLS.flat,
        trendTitle: TREND_TITLES[item.trend] || TREND_TITLES.flat,
        trendClass: `trend-indicator trend-${normalizedTrend}`,
        label: item.displayName || item.integrationCode
      };
    });
  }

  /**
   * @description Handles click on an integration row.
   * Dispatches integrationclick event with integrationCode.
   * @param {Event} event - Click event from a row
   */
  handleRowClick(event) {
    const code = event.currentTarget.dataset.code;
    if (code) {
      this.dispatchEvent(
        new CustomEvent("integrationclick", {
          detail: { integrationCode: code }
        })
      );
    }
  }

  /**
   * @description Handles keyboard activation on a row for accessibility.
   * Supports Enter/Space for activation and arrow keys for navigation.
   * @param {KeyboardEvent} event - Keydown event
   */
  handleKeyDown(event) {
    const errorRows = this.template.querySelectorAll(".error-row");
    const currentIndex = Array.from(errorRows).indexOf(event.target);

    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.handleRowClick(event);
      return;
    }

    // Arrow key navigation between error rows
    if (event.key === "ArrowDown") {
      event.preventDefault();
      const nextIndex = Math.min(currentIndex + 1, errorRows.length - 1);
      errorRows[nextIndex].focus();
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      const prevIndex = Math.max(currentIndex - 1, 0);
      errorRows[prevIndex].focus();
    }
  }
}
