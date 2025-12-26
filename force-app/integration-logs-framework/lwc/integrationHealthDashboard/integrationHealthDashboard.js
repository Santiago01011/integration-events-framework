import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getRecentLogs from '@salesforce/apex/IntegrationHealthController.getRecentLogs';
import getLogDetail from '@salesforce/apex/IntegrationHealthController.getLogDetail';
import getIntegrationSummaries from '@salesforce/apex/IntegrationHealthController.getIntegrationSummaries';
import getEventChannel from '@salesforce/apex/IntegrationHealthController.getEventChannel';
import { subscribe, unsubscribe, onError, isEmpEnabled } from 'lightning/empApi';
import logsApi from 'c/utilsLogsApi';

// Columns definition for the child table
const COLUMNS = [
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
            second: '2-digit'
        },
        fixedWidth: 200
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
        typeAttributes: { 
            rowActions: [{ label: 'View Details', name: 'view_details' }] 
        }
    }
];

export default class IntegrationHealthDashboard extends LightningElement {
    @track rows = [];
    @track columns = COLUMNS;
    @track isLoading = false;
    @track hasMore = false;
    @track lastUpdated;
    @track summaries;

    // Internal State
    currentFilters = {};    
    lastOccurredAt;
    lastId;
    pageSize = 20;

    showDetailDrawer = false;
    selectedRecord;
    
    // Filter State Mapping
    searchValue = '';
    observationType = '';
    integrationCode = '';
    correlationId = '';
    fromOccurredAt;
    toOccurredAt;

    refreshTrigger = 0;

    @wire(getIntegrationSummaries)
    wiredGetSummaries(result) {
        this.wiredSummariesResult = result;
        this.summaries = result;
    }

    wiredSummariesResult;
    channelSubscription;
    eventChannelName;
    empReconnectAttempts = 0;
    empReconnectMaxRetries = 3;
    empReconnectDelay = 5000;

    connectedCallback() {
        this.loadInitialData();
        this.initEventChannel();
    }

    disconnectedCallback() {
        this.unsubscribeFromEvents();
    }

    /**
     * @description Handles the 'filterschanged' event from c-ihd-filters
     */
    handleFiltersChanged(event) { 
        const { search, observationType, integrationCode, correlationId, from, to } = event.detail || {};
        this.searchValue = search || '';
        this.observationType = observationType || '';
        this.integrationCode = integrationCode || '';
        this.correlationId = correlationId || '';
        this.fromOccurredAt = from || null;
        this.toOccurredAt = to || null;
        this.loadInitialData();
    }

    /**
     * @description Handles the 'refresh' event
     */
    handleRefresh() {
        this.loadInitialData();
    }

    loadInitialData() {
        this.isLoading = true;
        this.refreshTrigger = this.refreshTrigger + 1;
        
        this.rows = []; 
        this.hasMore = false;

        this.fetchAndSetLogs({ append: false })
            .catch(error => {
                this.showError('Error refreshing data', this.resolveErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * @description Handles the 'rowaction' event from c-ihd-table
     */
    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;

        if (action.name === 'view_details') {
            this.loadAndDisplayDetails(row.Id);
        }
    }

    /**
     * @description Handles the 'loadmore' event from c-ihd-table
     */
    async handleLoadMoreData() {
        if (!this.hasMore || this.isLoading) {
            return;
        }
        this.isLoading = true;
        const lastRecord = this.rows.length > 0 ? this.rows[this.rows.length - 1] : null;

        try {
            const data = await logsApi.fetchPage(getRecentLogs, {
                pageSize: this.pageSize,
                search: this.searchValue,
                fromOccurredAt: this.fromOccurredAt,
                toOccurredAt: this.toOccurredAt,
                lastOccurredAt: lastRecord?.OccurredAt__c,
                lastId: lastRecord?.Id,
                correlationId: this.correlationId,
                observationType: this.observationType,
                integrationCode: this.integrationCode
            }, { force: false });

            const newLogs = (data.records || []).map(row => this.transformRow(row));            
            this.rows = [...this.rows, ...newLogs];
            this.hasMore = data.hasMore;

        } catch (error) {
            this.showError('Error loading more logs', this.resolveErrorMessage(error));
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Core data fetcher. Handles transformation of raw API data into table rows.
     */
    async fetchAndSetLogs({ append = false, force = false } = {}) {
        this.isLoading = true;
        try {
            const lastRecord = append && this.rows.length ? this.rows[this.rows.length - 1] : null;
            
            const data = await logsApi.fetchPage(getRecentLogs, {
                pageSize: this.pageSize,
                search: this.searchValue,
                fromOccurredAt: this.fromOccurredAt,
                toOccurredAt: this.toOccurredAt,
                lastOccurredAt: lastRecord?.OccurredAt__c,
                lastId: lastRecord?.Id,
                correlationId: this.correlationId,
                observationType: this.observationType,
                integrationCode: this.integrationCode
            }, { force });

            const rawRecords = data.records || [];
            const transformedRecords = rawRecords.map(row => this.transformRow(row));

            if (append) {
                this.rows = [...this.rows, ...transformedRecords];
            } else {
                this.rows = transformedRecords;
            }
            
            this.hasMore = data.hasMore;
            this.lastUpdated = new Date().toISOString();
            return data;
        } catch (error) {
            this.showError('Error loading logs', this.resolveErrorMessage(error));
            throw error;
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * @description Helper to format a raw record for the table
     */
    transformRow(record) {
        return {
            ...record,
            contextPreview: this.getContextPreview(record.Normalized_Context__c)
        };
    }

    getContextPreview(context) {
        if (!context) return '';
        const maxLength = 160;
        return context.length > maxLength ? context.substring(0, maxLength) + '...' : context;
    }

    async loadAndDisplayDetails(logId) {
        this.isLoading = true;
        try {
            const detailWrapper = await getLogDetail({ logId });
            this.selectedRecord = detailWrapper; 
            this.showDetailDrawer = true;
        } catch (error) {
            this.showError('Error loading log details', this.resolveErrorMessage(error));
        } finally {
            this.isLoading = false;
        }
    }

    handleCloseDetailDrawer() {
        this.showDetailDrawer = false;
        this.selectedRecord = null;
    }

    // --- EMP / Event Monitoring Logic ---

    async refreshLogs() {
        return this.fetchAndSetLogs({ append: false, force: true });
    }

    refreshSummaries() {
        if (this.wiredSummariesResult) {
            return refreshApex(this.wiredSummariesResult);
        }
        return Promise.resolve();
    }

    async initEventChannel() {
        if (!isEmpEnabled()) return;
        try {
            this.eventChannelName = await getEventChannel();
            this.subscribeToEvents();
        } catch (error) {
            this.showError('Error resolving event channel', this.resolveErrorMessage(error));
        }
    }

    subscribeToEvents() {
        if (!this.eventChannelName || !isEmpEnabled()) return;

        onError(error => {
            const errorMsg = this.resolveErrorMessage(error);
            if (this.isTokenExpiredError(errorMsg)) {
                this.handleTokenExpired();
            }
        });

        subscribe(this.eventChannelName, -1, async (event) => {
            const payload = event.data.payload;
            this.showToast('New Event', `${payload.Context__c}`, 'info');
            this.empReconnectAttempts = 0;
            try {
                try {
                    logsApi.invalidateForRecord(payload);
                } catch {
                    logsApi.clearCache();
                }
                await Promise.all([this.fetchAndSetLogs({ append: false, force: true }), this.refreshSummaries()]);
                this.lastUpdated = new Date().toISOString();
            } catch (refreshError) {
                this.showError('Error refreshing data', this.resolveErrorMessage(refreshError));
            }
        })
        .then(subscription => {
            this.channelSubscription = subscription;
            this.empReconnectAttempts = 0;
        })
        .catch(error => {
            const errorMsg = this.resolveErrorMessage(error);
            if (this.isTokenExpiredError(errorMsg)) {
                this.handleTokenExpired();
            } else {
                this.showError('Error subscribing to events', errorMsg);
            }
        });
    }

    isTokenExpiredError(errorMsg) {
        if (!errorMsg) return false;
        return errorMsg.includes('403') || errorMsg.includes('Unknown client') || errorMsg.includes('Session') || errorMsg.includes('Unauthorized');
    }

    handleTokenExpired() {
        if (this.empReconnectAttempts >= this.empReconnectMaxRetries) {
            this.showError('Connection Lost', 'Lost connection to real-time updates. Please refresh the page.');
            return;
        }
        this.empReconnectAttempts++;
        this.unsubscribeFromEvents();
        this.subscribeToEvents();
    }

    unsubscribeFromEvents() {
        if (this.channelSubscription) {
            unsubscribe(this.channelSubscription, () => {});
        }
    }

    // --- Tab and Summary Card Logic ---

    _activeTab = 'summary';

    get activeTab() { return this._activeTab; }
    set activeTab(value) {
        this._activeTab = value;
        this.updateTabset();
    }

    get summariesData() {
        return this.summaries && this.summaries.data ? this.summaries.data : undefined;
    }

    get summariesError() {
        return this.summaries && this.summaries.error ? this.summaries.error : undefined;
    }

    get initialLoadDone() {
        return this.summariesData || this.summariesError;
    }

    get globalStats() {
        const data = this.summariesData || [];
        let total = 0;
        let errors = 0;
        let success = 0;

        data.forEach(item => {
            total += item.totalEvents || 0;
            errors += item.errorCount || 0;
            success += item.successCount || 0;
        });

        const successRate = total > 0 ? Math.round((success / total) * 100) : 100;
        const errorRate = 100 - successRate;

        let status = 'HEALTHY';
        let statusClass = 'slds-badge slds-theme_success';
        
        if (successRate < 90) {
            status = 'CRITICAL';
            statusClass = 'slds-badge slds-theme_error';
        } else if (successRate < 98) {
            status = 'WARNING';
            statusClass = 'slds-badge slds-theme_warning';
        }

        return {
            total,
            errors,
            success,
            successRate,
            errorRate,
            status,
            statusClass,
            successRateLabel: 'Success',
            errorRateLabel: 'Errors',
            progressStyle: `background: linear-gradient(90deg, #04844b ${successRate}%, #c23934 ${successRate}%); width: 100%;`
        };
    }

    get systemPulseStats() {
        const stats = this.globalStats;
        return [
            {
                id: 'total',
                label: 'Total Events',
                value: stats.total,
                isDateTime: false,
                badgeTheme: null
            },
            {
                id: 'success',
                label: 'Successful',
                value: stats.success,
                isDateTime: false,
                badgeTheme: 'success'
            },
            {
                id: 'errors',
                label: 'Errors',
                value: stats.errors,
                isDateTime: false,
                badgeTheme: 'error'
            }
        ];
    }

    handleTabSelect(event) {
        this._activeTab = event.detail.value;
    }

    updateTabset() {
        const tabset = this.template.querySelector('lightning-tabset');
        if (tabset) {
            tabset.activeTabValue = this._activeTab;
        }
    }

    handleSummaryCardClick() {
        this.activeTab = 'filters';
        this.searchValue = '';
        this.loadInitialData();
    }

    handleIntegrationCardClick(event) {
        const detail = event.detail || {};
        const normalizedContext = detail.normalizedContext;
        const fallbackTerm = detail.displayName || detail.integrationCode || '';
        
        this.searchValue = normalizedContext || fallbackTerm;
        this.integrationCode = ''; 
        
        this.loadInitialData();
        this.activeTab = 'filters';
    }

    // --- Utilities ---

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    showError(title, message) {
        this.showToast(title, message, 'error');
    }

    resolveErrorMessage(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) return error.body.map(entry => entry.message).join(', ');
        if (error.body && typeof error.body.message === 'string') return error.body.message;
        if (typeof error.message === 'string') return error.message;
        if (typeof error.body === 'string') return error.body;
        return JSON.stringify(error);
    }
}