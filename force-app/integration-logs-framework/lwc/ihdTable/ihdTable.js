import { LightningElement, api } from 'lwc';

/**
 * @description A generic, reusable Salesforce Datatable wrapper.
 * completely agnostic of the data it displays.
 */
export default class IhdTable extends LightningElement {
    /**
     * @description The data rows to display.
     */
    @api rows = [];

    /**
     * @description The column definitions (standard lightning-datatable format).
     */
    @api columns = [];

    /**
     * @description Whether the table is loading data.
     */
    @api isLoading = false;

    /**
     * @description Enables infinite loading features.
     */
    @api enableInfiniteLoading = false;

    /**
     * @description The field name currently sorted by.
     */
    @api sortedBy;

    /**
     * @description The sort direction ('asc' or 'desc').
     */
    @api sortedDirection;

    /**
     * @description Message to show when no rows are present.
     */
    @api noDataMessage = 'No items found.';

    // --- Getters ---

    get hasRows() {
        return Array.isArray(this.rows) && this.rows.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.hasRows;
    }

    handleRowAction(event) {
        this.dispatchEvent(new CustomEvent('rowaction', {
            detail: event.detail
        }));
    }

    handleSort(event) {
        this.dispatchEvent(new CustomEvent('sort', {
            detail: {
                fieldName: event.detail.fieldName,
                sortDirection: event.detail.sortDirection
            }
        }));
    }

    handleLoadMore() {
        if (!this.isLoading) {
            this.dispatchEvent(new CustomEvent('loadmore'));
        }
    }
}