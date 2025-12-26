import { LightningElement, api } from 'lwc';

/**
 * @description A card component to display the summary of a single integration.
 * Reuses the ihdStatsCard component for consistent UI and reduced code duplication.
 */
export default class IhdIntegrationSummaryCard extends LightningElement {
    @api summary;
    @api maxEvents = 1;

    get progressPercentage() {
        if (!this.summary || !this.summary.totalEvents) {
            return 0;
        }
        return Math.round((this.summary.successCount / this.summary.totalEvents) * 100);
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
                id: 'lastRun',
                label: 'Last Run',
                value: this.summary.lastOccurredAt,
                isDateTime: true
            },
            {
                id: 'totalEvents',
                label: 'Total Events',
                value: this.summary.totalEvents,
                isDateTime: false,
                badgeTheme: 'default'
            }
        ];

        return stats;
    }

    handleCardClick() {
        const event = new CustomEvent('cardclick', {
            detail: {
                normalizedContext: this.summary.normalizedContext,
                integrationCode: this.summary.integrationCode,
                displayName: this.summary.displayName
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(event);
    }
}
