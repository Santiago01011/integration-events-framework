import { LightningElement, api } from 'lwc';

/**
 * @description A card component to display the summary of a single integration.
 * Reuses the ihdStatsCard component for consistent UI and reduced code duplication.
 */
export default class IhdIntegrationSummaryCard extends LightningElement {
    /**
     * @description The integration summary data from the Apex controller.
     * @type {object}
     */
    @api summary;

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
                value: this.summary.lastRunDate,
                isDateTime: true
            },
            {
                id: 'totalJobs',
                label: 'Total Jobs',
                value: this.summary.totalJobs,
                isDateTime: false,
                badgeTheme: 'default'
            },
            {
                id: 'lastError',
                label: 'Last Error Date',
                value: this.summary.lastErrorDate || 'N/A',
                isDateTime: !!this.summary.lastErrorDate
            }
        ];

        return stats;
    }

    handleCardClick() {
        const event = new CustomEvent('cardclick', {
            detail: {
                integrationName: this.summary.integrationName
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(event);
    }
}
