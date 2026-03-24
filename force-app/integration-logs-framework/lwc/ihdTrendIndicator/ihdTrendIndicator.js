import { LightningElement, api } from "lwc";

const SPARKLINE_WIDTH = 100;
const SPARKLINE_HEIGHT = 30;

/**
 * @description Trend indicator component displaying an inline SVG sparkline
 * with delta percentage and directional arrow. Color-coded by trend direction:
 * green for positive (fewer errors), red for negative (more errors), gray for flat.
 */
export default class IhdTrendIndicator extends LightningElement {
  /**
   * @description The hourly trend result from getHourlyTrend Apex.
   * Contains points[], direction ('up'|'down'|'flat'), and delta (percentage).
   * @type {object}
   */
  @api trendData;

  /**
   * @description Whether the data is currently loading.
   * @type {boolean}
   */
  @api isLoading = false;

  /**
   * @description Custom label for the trend title. Defaults to "Hourly Trend".
   * @type {string}
   */
  @api label = "Hourly Trend";

  /**
   * @description Computes SVG polyline points from the trend data.
   * Normalizes data to fit the viewBox (100x30).
   * @returns {string} Space-separated "x,y" coordinate pairs
   */
  get sparklinePoints() {
    if (!this.trendData || !this.trendData.points) return "";
    const points = this.trendData.points;
    if (points.length < 2) return "";

    const max = Math.max(...points.map((p) => p.total));
    return points
      .map((p, i) => {
        const x =
          points.length > 1 ? (i / (points.length - 1)) * SPARKLINE_WIDTH : 0;
        const y =
          SPARKLINE_HEIGHT - (max > 0 ? (p.total / max) * SPARKLINE_HEIGHT : 0);
        return `${x},${y}`;
      })
      .join(" ");
  }

  /**
   * @description Whether there is enough data to render the sparkline.
   * @returns {boolean}
   */
  get hasData() {
    return (
      this.trendData &&
      this.trendData.points &&
      this.trendData.points.length >= 2
    );
  }

  /**
   * @description The stroke color for the sparkline based on trend direction.
   * @returns {string} CSS custom property value
   */
  get strokeColor() {
    if (!this.trendData) return "var(--slds-g-color-text-3, #747474)";
    if (this.trendData.direction === "up") {
      return "var(--slds-g-color-success-base-40, #04844b)";
    }
    if (this.trendData.direction === "down") {
      return "var(--slds-g-color-error-base-50, #ba0517)";
    }
    return "var(--slds-g-color-text-3, #747474)";
  }

  /**
   * @description The CSS class for the delta text based on trend direction.
   * @returns {string}
   */
  get deltaClass() {
    if (!this.trendData) return "delta-text";
    if (this.trendData.direction === "up") return "delta-text delta-positive";
    if (this.trendData.direction === "down") return "delta-text delta-negative";
    return "delta-text delta-flat";
  }

  /**
   * @description The formatted delta display string.
   * @returns {string} e.g. "+3.2% vs last hour" or "-12.0% vs last hour"
   */
  get deltaDisplay() {
    if (!this.trendData || this.trendData.delta === null) return "--";
    const delta = this.trendData.delta;
    const sign = delta > 0 ? "+" : "";
    return `${sign}${delta}% vs last hour`;
  }

  /**
   * @description The arrow icon name based on trend direction.
   * @returns {string}
   */
  get arrowIcon() {
    if (!this.trendData) return "utility:dash";
    if (this.trendData.direction === "up") return "utility:arrowup";
    if (this.trendData.direction === "down") return "utility:arrowdown";
    return "utility:dash";
  }

  /**
   * @description The viewBox attribute for the SVG.
   * @returns {string}
   */
  get viewBox() {
    return `0 0 ${SPARKLINE_WIDTH} ${SPARKLINE_HEIGHT}`;
  }
}
