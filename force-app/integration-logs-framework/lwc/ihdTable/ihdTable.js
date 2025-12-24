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

    _columns;


    get displayRows() {
        return (this.rows || []).map(record => ({
            ...record,
            contextPreview: this.getContextPreview(record.Normalized_Context__c)
        }));
    }

    getContextPreview(context) {
        if (!context) return '';
        const maxLength = 160;
        return context.length > maxLength ? context.substring(0, maxLength) + '...' : context;
    }

    get columns() {
        if (!this._columns) {
            this._columns = [
                {
                    label: 'Occurred At',
                    fieldName: 'OccurredAt__c',
                    type: 'date',
                    typeAttributes: {
                        year: 'numeric',
                        month: '2-digit',
                        day: '2-digit',
                        hour: '2-digit',
                        minute: '2-digit',
                        second: '2-digit',
                        timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone
                    }
                },
                {
                    label: 'Observation',
                    fieldName: 'ObservationType__c',
                    type: 'text'
                },
                {
                    label: 'Integration',
                    fieldName: 'IntegrationCode__c',
                    type: 'text'
                },
                {
                    label: 'Context',
                    fieldName: 'contextPreview',
                    type: 'text',
                    wrapText: true,
                    cellAttributes: { title: { fieldName: 'Normalized_Context__c' } }
                },
                {
                    label: 'Correlation',
                    fieldName: 'CorrelationId__c',
                    type: 'text',
                    wrapText: true
                },
                {
                    type: 'action',
                    typeAttributes: { rowActions: [{ label: 'View Details', name: 'view_details' }] }
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

    handleLoadMore() {
        if (this.hasMore && !this.isLoading) {
            this.dispatchEvent(new CustomEvent('loadnext'));
        }
    }
}

