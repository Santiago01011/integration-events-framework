import { LightningElement, api } from "lwc";

// Custom Labels
import IEF_Last_Run from "@salesforce/label/c.IEF_Last_Run";
import IEF_Total_Events from "@salesforce/label/c.IEF_Total_Events";
import IEF_Transport from "@salesforce/label/c.IEF_Transport";
import IEF_Components from "@salesforce/label/c.IEF_Components";

/**
 * @description A card component to display the summary of a single integration.
 * Reuses the iefStatsCard component for consistent UI and reduced code duplication.
 */
export default class IefIntegrationSummaryCard extends LightningElement {
  labels = {
    IEF_Last_Run,
    IEF_Total_Events,
    IEF_Transport,
    IEF_Components
  };

  @api summary;
  @api maxEvents = 1;

  get progressPercentage() {
    if (!this.summary || !this.summary.totalEvents) {
      return 0;
    }
    return Math.round(
      (this.summary.successCount / this.summary.totalEvents) * 100
    );
  }

  get successPercentage() {
    return this.progressPercentage;
  }

  get errorPercentage() {
    return 100 - this.successPercentage;
  }

  /**
   * @description Transforms the summary object into a stats array for the iefStatsCard component.
   * @returns {Array} Array of stat objects
   */
  get summaryStats() {
    if (!this.summary) {
      return [];
    }

    const stats = [
      {
        id: "lastRun",
        label: IEF_Last_Run,
        value: this.summary.lastOccurredAt,
        isDateTime: true
      },
      {
        id: "totalEvents",
        label: IEF_Total_Events,
        value: this.summary.totalEvents,
        isDateTime: false,
        badgeTheme: "default"
      }
    ];

    if (
      this.summary.componentLabels &&
      this.summary.componentLabels.length > 1
    ) {
      stats.push({
        id: "components",
        label: IEF_Components,
        value: this.summary.componentLabels.join(", "),
        isDateTime: false
      });
    }

    return stats;
  }

  handleCardClick() {
    const event = new CustomEvent("cardclick", {
      detail: {
        normalizedContext: this.summary.normalizedContext,
        integrationCode: this.summary.integrationCode,
        displayName: this.summary.displayName,
        groupName: this.summary.groupName
      },
      bubbles: true,
      composed: true
    });
    this.dispatchEvent(event);
  }
}
