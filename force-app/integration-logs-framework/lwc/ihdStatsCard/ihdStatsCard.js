import { LightningElement, api } from 'lwc';

/**
 * @description A reusable stats card component that displays a progress bar and a list of statistics.
 * Used in both integration summary views and overall health overviews.
 */
export default class IhdStatsCard extends LightningElement {
    /**
     * @description The card title.
     * @type {string}
     */
    @api title = '';

    /**
     * @description The success percentage (0-100).
     * @type {number}
     */
    @api successPercentage = 0;

    /**
     * @description The error percentage (0-100).
     * @type {number}
     */
    @api errorPercentage = 0;

    /**
     * @description Label for the success bar.
     * @type {string}
     */
    @api successLabel = 'Success';

    /**
     * @description Label for the error bar.
     * @type {string}
     */
        @api errorLabel = 'Error';

    _stats = [];

    /**
     * @description Array of stat objects to display.
     * Each stat object should have:
     * - id: unique identifier
     * - label: display label
     * - value: the value to display
     * - badgeTheme: (optional) badge theme ('error', 'success', or null for no badge)
     * - isDateTime: (optional) whether the value is a datetime to format
     * @type {Array}
     */
    @api
    get stats() {
        return this._stats;
    }
    set stats(value) {
        if (value) {
            this._stats = value.map(stat => ({
                ...stat,
                badgeClass: this.getBadgeClass(stat.badgeTheme)
            }));
        } else {
            this._stats = [];
        }
    }

    /**
     * @description Handles the click event on the card and dispatches a 'cardclick' event.
     */
    handleCardClick() {
        const cardClickEvent = new CustomEvent('cardclick');
        this.dispatchEvent(cardClickEvent);
    }

        /**
     * @description Generates the SLDS badge class based on the theme.
     * @param {string} theme - The badge theme ('error', 'success', or any other string for default blue).
     * @returns {string} The complete badge class string
     */
    getBadgeClass(theme) {
        if (!theme) return '';
        const baseClass = 'slds-badge';
        if (theme === 'success' || theme === 'error') {
            return `${baseClass} slds-theme_${theme}`;
        }
        return baseClass;
    }
}
