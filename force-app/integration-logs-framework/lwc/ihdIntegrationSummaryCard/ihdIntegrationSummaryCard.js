import { LightningElement, api } from "lwc";

// Custom Labels
import IHD_Last_Run from "@salesforce/label/c.IHD_Last_Run";
import IHD_Total_Events from "@salesforce/label/c.IHD_Total_Events";
import IHD_Transport from "@salesforce/label/c.IHD_Transport";
import IHD_Components from "@salesforce/label/c.IHD_Components";

/**
 * @description A card component to display the summary of a single integration.
 * Reuses the ihdStatsCard component for consistent UI and reduced code duplication.
 */
export default class IhdIntegrationSummaryCard extends LightningElement {
  labels = {
    IHD_Last_Run,
    IHD_Total_Events,
    IHD_Transport,
    IHD_Components
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
   * @description Transforms the summary object into a stats array for the ihdStatsCard component.
   * @returns {Array} Array of stat objects
   */
  get summaryStats() {
    if (!this.summary) {
      return [];
    }

    const stats = [
      {
        id: "lastRun",
        label: IHD_Last_Run,
        value: this.summary.lastOccurredAt,
        isDateTime: true
      },
      {
        id: "totalEvents",
        label: IHD_Total_Events,
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
        label: IHD_Components,
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
