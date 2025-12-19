import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getRecentLogs from '@salesforce/apex/IntegrationHealthController.getRecentLogs';
import getLogDetail from '@salesforce/apex/IntegrationHealthController.getLogDetail';
import getAggregates from '@salesforce/apex/IntegrationHealthController.getAggregates';
import setLogProcessed from '@salesforce/apex/IntegrationHealthController.setLogProcessed';
import getIntegrationSummaries from '@salesforce/apex/IntegrationHealthController.getIntegrationSummaries';
import { subscribe, unsubscribe, onError, isEmpEnabled } from 'lightning/empApi';
import logsApi from 'c/utilsLogsApi';

export default class IntegrationHealthDashboard extends LightningElement {
    logs = [];
    isLoading = false;
    showDetailDrawer = false;
    selectedRecord;
    pageSize = 20;
    statusFilter = 'All';
    searchValue = '';
    currentPage = 1;
    lastCreatedDate = null;
    lastId = null;
    hasMore = false;
    errorCount = 0;
    processedCount = 0;
    lastUpdated;
    aggregatesLoaded = false;
    refreshTrigger = 0;

    /**
     * @description Wired property to get the integration summaries from the Apex controller.
     */
    @wire(getIntegrationSummaries)
    wiredGetSummaries(result) {
        this.wiredSummariesResult = result;
        this.summaries = result;
    }

    
    wiredSummariesResult;
    wiredLogsResult;
    wiredAggregatesResult;
    channelSubscription;
    empReconnectAttempts = 0;
    empReconnectMaxRetries = 3;
    empReconnectDelay = 5000;

    get hasLogs() {
        return Array.isArray(this.logs) && this.logs.length > 0;
    }

    // logs are fetched imperatively via logsApi.fetchPage to enable client-side cache and event-driven invalidation

    @wire(getAggregates)
    wiredGetAggregates(result) {
        this.wiredAggregatesResult = result;
        const { data, error } = result;
        if (data) {
            this.errorCount = data.errorCount || 0;
            this.processedCount = data.processedCount || 0;
            this.aggregatesLoaded = true;
        } else if (error) {
            this.showError('Error loading aggregates', this.resolveErrorMessage(error));
            this.aggregatesLoaded = true;
        }
    }

    connectedCallback() {
        this.loadInitialData();
        this.subscribeToEvents();
    }

    disconnectedCallback() {
        this.unsubscribeFromEvents();
    }

    loadInitialData() {
        this.isLoading = true;
        this.currentPage = 1;
        this.lastCreatedDate = null;
        this.lastId = null;
        this.refreshTrigger = this.refreshTrigger + 1;
        Promise.all([this.fetchAndSetLogs({ append: false }), this.refreshAggregates()])
            .catch(error => {
                this.showError('Error refreshing data', this.resolveErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get statusFilterValue() {
        return this.statusFilter === 'All' ? null : this.statusFilter;
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
        this.loadInitialData();
    }

    handleSearchChange(event) {
        this.searchValue = event.detail.value;
        this.loadInitialData();
    }

    handleClearFilters() {
        this.statusFilter = 'All';
        this.searchValue = '';
        this.loadInitialData();
    }

    handleRefresh() {
        this.loadInitialData();
    }

    handleTableAction(event) {
        const { name, id } = event.detail;
        if (name === 'view_details') {
            this.loadAndDisplayDetails(id);
            return;
        }
        if (name === 'mark_processed') {
            this.markAsProcessed([id]);
            return;
        }
        if (name === 'reopen') {
            this.reopen([id]);
        }
    }

    async loadAndDisplayDetails(logId) {
        try {
            this.selectedRecord = await getLogDetail({ logId });
            this.showDetailDrawer = true;
        } catch (error) {
            this.showError('Error loading log details', this.resolveErrorMessage(error));
        }
    }

    async handleLoadNext() {
        if (!this.hasMore || this.isLoading) {
            return;
        }
        this.isLoading = true;
        const lastRecord = this.logs.length > 0 ? this.logs[this.logs.length - 1] : null;
        try {
            const data = await logsApi.fetchPage(getRecentLogs, {
                pageSize: this.pageSize,
                statusFilter: this.statusFilterValue,
                search: this.searchValue,
                lastCreatedDate: lastRecord?.CreatedDate,
                lastId: lastRecord?.Id
            }, { force: false });
            const newLogs = data.records || [];
            this.logs = [...this.logs, ...newLogs];
            this.hasMore = data.hasMore;
        } catch (error) {
            this.showError('Error loading more logs', this.resolveErrorMessage(error));
        } finally {
            this.isLoading = false;
        }
    }

    markAsProcessed(recordIds) {
        this.isLoading = true;
        setLogProcessed({ logIds: recordIds, processed: true })
            .then(() => {
                this.showToast('Success', 'Log marked as processed', 'success');
                return Promise.all([this.fetchAndSetLogs({ append: false, force: true }), this.refreshAggregates()]);
            })
            .then(() => {
                this.showDetailDrawer = false;
            })
            .catch(error => {
                this.showError('Error updating log', this.resolveErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    reopen(recordIds) {
        this.isLoading = true;
        setLogProcessed({ logIds: recordIds, processed: false })
            .then(() => {
                this.showToast('Success', 'Log reopened', 'success');
                return Promise.all([this.fetchAndSetLogs({ append: false, force: true }), this.refreshAggregates()]);
            })
            .then(() => {
                this.showDetailDrawer = false;
            })
            .catch(error => {
                this.showError('Error updating log', this.resolveErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleCloseDetailDrawer() {
        this.showDetailDrawer = false;
        this.selectedRecord = null;
    }

    handleDetailMarkProcessed(event) {
        this.markAsProcessed([event.detail]);
    }

    handleDetailReopen(event) {
        this.reopen([event.detail]);
    }

    async fetchAndSetLogs({ append = false, force = false } = {}) {
        this.isLoading = true;
        try {
            const lastRecord = append && this.logs.length ? this.logs[this.logs.length - 1] : null;
            const data = await logsApi.fetchPage(getRecentLogs, {
                pageSize: this.pageSize,
                statusFilter: this.statusFilterValue,
                search: this.searchValue,
                lastCreatedDate: lastRecord?.CreatedDate,
                lastId: lastRecord?.Id
            }, { force });

            const records = data.records || [];
            if (append) {
                this.logs = [...this.logs, ...records];
            } else {
                this.logs = records;
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

    async refreshLogs() {
        // legacy hook - route to fetchAndSetLogs for imperative fetching
        return this.fetchAndSetLogs({ append: false, force: true });
    }

    async refreshAggregates() {
        const promises = [];
        if (this.wiredAggregatesResult) {
            promises.push(refreshApex(this.wiredAggregatesResult));
        }
        promises.push(this.refreshSummaries());
        return Promise.all(promises);
    }

    refreshSummaries() {
        if (this.wiredSummariesResult) {
            return refreshApex(this.wiredSummariesResult);
        }
        return Promise.resolve();
    }

    subscribeToEvents() {
        if (!isEmpEnabled()) {
            return;
        }

        onError(error => {
            const errorMsg = this.resolveErrorMessage(error);
            console.warn('[EMP] Subscription error:', errorMsg);
            
            if (this.isTokenExpiredError(errorMsg)) {
                this.handleTokenExpired();
            }
        });

        subscribe('/event/IntegrationEvent__e', -1, async (event) => {
            const payload = event.data.payload;
            this.showToast('New Log', `${payload.Context__c}`, 'warning');
            this.empReconnectAttempts = 0;
            // Invalidate cache entries that may be affected by this event and refetch
            try {
                try {
                    logsApi.invalidateForRecord(payload);
                } catch {
                    // safe fallback to clearing entire cache
                    logsApi.clearCache();
                }
                await Promise.all([this.fetchAndSetLogs({ append: false, force: true }), this.refreshAggregates()]);
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
                console.warn('[EMP] Subscribe error:', errorMsg);
                
                if (this.isTokenExpiredError(errorMsg)) {
                    this.handleTokenExpired();
                } else {
                    this.showError('Error subscribing to events', errorMsg);
                }
            });
    }

    isTokenExpiredError(errorMsg) {
        if (!errorMsg) return false;
        return errorMsg.includes('403') || 
               errorMsg.includes('Unknown client') || 
               errorMsg.includes('Session') ||
               errorMsg.includes('Unauthorized');
    }

    handleTokenExpired() {
        if (this.empReconnectAttempts >= this.empReconnectMaxRetries) {
            this.showError(
                'Connection Lost', 
                'Lost connection to real-time updates. Please refresh the page.'
            );
            return;
        }

        this.empReconnectAttempts++;
        console.warn(`[EMP] Token expired. Reconnect attempt ${this.empReconnectAttempts} of ${this.empReconnectMaxRetries}`);
        
        this.unsubscribeFromEvents();
        this.subscribeToEvents();
    }

    unsubscribeFromEvents() {
        if (this.channelSubscription) {
            unsubscribe(this.channelSubscription, () => {});
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    showError(title, message) {
        this.showToast(title, message, 'error');
    }

    resolveErrorMessage(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map(entry => entry.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        if (typeof error.message === 'string') {
            return error.message;
        }
        if (typeof error.body === 'string') {
            return error.body;
        }
        return JSON.stringify(error);
    }

    get totalLogs() {
        return this.errorCount + this.processedCount;
    }

    calculatePercentage(count) {
        if (this.totalLogs === 0) {
            return 0;
        }
        return Math.round((count / this.totalLogs) * 100);
    }

    get errorPercentage() {
        return this.calculatePercentage(this.errorCount);
    }

    get processedPercentage() {
        return this.calculatePercentage(this.processedCount);
    }

    get zeroPercentage() {
        return 0;
    }

    /**
     * @description Transforms component data into a stats array for the ihdStatsCard component.
     * @returns {Array} Array of stat objects for overall statistics
     */
        get overallStats() {
        const stats = [
            {
                id: 'totalLogs',
                label: 'Total Logs',
                value: this.totalLogs,
                isDateTime: false,
                badgeTheme: 'default'
            },
            {
                id: 'errorCount',
                label: 'Error Logs',
                value: this.errorCount,
                isDateTime: false,
                badgeTheme: 'error'
            },
            {
                id: 'processedCount',
                label: 'Processed Logs',
                value: this.processedCount,
                isDateTime: false,
                badgeTheme: 'success'
            },
            {
                id: 'lastUpdated',
                label: 'Last Updated',
                value: this.lastUpdated,
                isDateTime: true
            }
        ];

        return stats;
    }

    _activeTab = 'summary';

    get activeTab() {
        return this._activeTab;
    }

    set activeTab(value) {
        this._activeTab = value;
        this.updateTabset();
    }

    /**
     * @description Determines if the initial data load has completed (either with data or an error).
     * @returns {boolean}
     */
    get initialLoadDone() {
        return this.summariesData || this.summariesError;
    }

    /**
     * Safe accessor for wired summaries data used in the template.
     */
    get summariesData() {
        return this.summaries && this.summaries.data ? this.summaries.data : undefined;
    }

    /**
     * Safe accessor for wired summaries error used in the template.
     */
    get summariesError() {
        return this.summaries && this.summaries.error ? this.summaries.error : undefined;
    }

    /**
     * @description Synchronizes the component's state with the active tab selected by the user.
     * @param {CustomEvent} event The `select` event from the lightning-tabset.
     */
    handleTabSelect(event) {
        this._activeTab = event.detail.value;
    }

    /**
     * @description Forces the lightning-tabset component to update its active tab value.
     * This ensures the tabset UI stays in sync with the component's internal state.
     */
    updateTabset() {
        const tabset = this.template.querySelector('lightning-tabset');
        if (tabset) {
            tabset.activeTabValue = this._activeTab;
        }
    }

    /**
     * @description Handles the click event from the summary card and navigates to the filters tab.
     */
    handleSummaryCardClick() {
        this.activeTab = 'filters';
        this.searchValue = '';
    }

    /**
     * @description Handles the click event from an integration summary card, sets the filter, and navigates to the filters tab.
     * @param {CustomEvent} event The event dispatched from the child component.
     */
    handleIntegrationCardClick(event) {
        this.searchValue = event.detail.integrationName;
        this.loadInitialData();
        this.activeTab = 'filters';
    }
}