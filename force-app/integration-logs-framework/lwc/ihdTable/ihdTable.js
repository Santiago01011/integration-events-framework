import { LightningElement, api, track } from 'lwc';

/**
 * @description A reusable data table component for displaying logs.
 * It supports row actions, row selection, and loading more data.
 * @example
 * <c-ihd-table
 *      rows={logRows}
 *      is-loading={isLoading}
 *      has-more={hasMoreData}
 *      onaction={handleRowAction}
 *      onrowclick={handleRowClick}
 *      onloadnext={handleLoadNext}>
 * </c-ihd-table>
 */
export default class IhdTable extends LightningElement {
    /**
     * @description The rows to display in the table.
     * @type {Array}
     */
    @api rows = [];

    /**
     * @description Whether the table is in a loading state.
     * @type {boolean}
     */
    @api isLoading = false;

    /**
     * @description The field to sort the table by.
     * @type {string}
     */
    @api sortedBy;

    /**
     * @description Whether there are more rows to load.
     * @type {boolean}
     */
    @api hasMore = false;

    /**
     * @description Whether more rows are currently being loaded.
     * @type {boolean}
     */
    @track isMoreLoading = false;

    // internal tracking to preserve scroll position when more rows are loaded
    _lastScrollTop = 0;
    _prevRowsLength = 0;
    _pendingRestore = false;

    _columns;

    get processedRows() {
        return (this.rows || []).map(record => ({
            ...record,
            statusLabel: record.Processed__c ? 'Processed' : 'Error',
            statusClass: record.Processed__c ? 'slds-text-color_success' : 'slds-text-color_error',
            messageSummary: this.getMessageSummary(record.Message__c)
        }));
    }

    getMessageSummary(message) {
        if (!message) return '';
        const maxLength = 100;
        return message.length > maxLength ? message.substring(0, maxLength) + '...' : message;
    }

    rowActionsProvider = (row, doneCallback) => {
        const actions = [{ label: 'View Details', name: 'view_details' }];
        if (row.Processed__c) {
            actions.push({ label: 'Reopen', name: 'reopen' });
        } else {
            actions.push({ label: 'Mark Processed', name: 'mark_processed' });
        }
        doneCallback(actions);
    };

    get columns() {
        if (!this._columns) {
            this._columns = [
                {
                    label: 'Time',
                    fieldName: 'CreatedDate',
                    type: 'date',
                    initialWidth: 180,
                    typeAttributes: {
                        day: '2-digit',
                        month: '2-digit',
                        year: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    },
                    sortable: true
                },
                {
                    label: 'Context',
                    fieldName: 'Context__c',
                    type: 'text',
                    initialWidth: 180
                },
                {
                    label: 'Message Summary',
                    fieldName: 'messageSummary',
                    type: 'text',
                    wrapText: true,
                    cellAttributes: { title: { fieldName: 'messageSummary' } }
                },
                {
                    label: 'Source',
                    fieldName: 'Source__c',
                    type: 'text',
                    initialWidth: 120
                },
                {
                    label: 'Status',
                    fieldName: 'statusLabel',
                    type: 'text',
                    initialWidth: 120,
                    cellAttributes: {
                        class: { fieldName: 'statusClass' }
                    }
                },
                {
                    type: 'action',
                    typeAttributes: { rowActions: this.rowActionsProvider },
                    initialWidth: 80
                }
            ];
        }
        return this._columns;
    }

    get hasRows() {
        return Array.isArray(this.rows) && this.rows.length > 0;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        this.dispatchEvent(new CustomEvent('action', {
            detail: {
                name: actionName,
                id: row.Id
            }
        }));
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length > 0) {
            this.dispatchEvent(new CustomEvent('rowclick', {
                detail: selectedRows[0].Id
            }));
        }
    }

    handleScroll(event) {
        const target = event.target;
        if (target.scrollHeight - target.scrollTop <= target.clientHeight + 1) {
            if (this.hasMore && !this.isMoreLoading) {
                // remember current scroll position to restore after parent appends rows
                this._lastScrollTop = target.scrollTop;
                this._pendingRestore = true;
                this.isMoreLoading = true;
                this.dispatchEvent(new CustomEvent('loadnext'));
                // safety: remove the loading state after a short time if parent doesn't update
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    // only clear if parent hasn't already cleared it
                    this.isMoreLoading = false;
                }, 10000);
            }
        }
    }

    renderedCallback() {
        // If parent appended rows and we flagged a pending restore, restore scrollTop.
        const container = this.template.querySelector('.table-container');
        const currentLength = Array.isArray(this.rows) ? this.rows.length : 0;

        // If rows increased because of a load-next, restore scroll
        if (this._pendingRestore && container) {
            // restore asynchronously to ensure DOM finished updating
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                try {
                    // Keep user roughly where they were — set scrollTop to previous position
                    container.scrollTop = this._lastScrollTop;
                } catch {
                    // no-op: if restore fails, don't throw
                }
                this._pendingRestore = false;
                // clear loading indicator; parent may also clear it
                this.isMoreLoading = false;
            }, 0);
        }

        // keep track of length for future comparisons
        this._prevRowsLength = currentLength;
    }
}