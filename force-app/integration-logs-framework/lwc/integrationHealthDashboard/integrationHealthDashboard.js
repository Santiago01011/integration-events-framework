import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getRecentLogs from '@salesforce/apex/IntegrationHealthController.getRecentLogs';
import getLogDetail from '@salesforce/apex/IntegrationHealthController.getLogDetail';
import getIntegrationSummaries from '@salesforce/apex/IntegrationHealthController.getIntegrationSummaries';
import getEventChannel from '@salesforce/apex/IntegrationHealthController.getEventChannel';
import { subscribe, unsubscribe, onError, isEmpEnabled } from 'lightning/empApi';
import logsApi from 'c/utilsLogsApi';

export default class IntegrationHealthDashboard extends LightningElement {
    logs = [];
    isLoading = false;
    showDetailDrawer = false;
    selectedRecord;
    pageSize = 20;
    searchValue = '';
    observationType = '';
    integrationCode = '';
    correlationId = '';
    fromOccurredAt;
    toOccurredAt;
    currentPage = 1;
    hasMore = false;
    lastUpdated;
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
    channelSubscription;
    eventChannelName;
    empReconnectAttempts = 0;
    empReconnectMaxRetries = 3;
    empReconnectDelay = 5000;

    get hasLogs() {
        return Array.isArray(this.logs) && this.logs.length > 0;
    }

    // logs are fetched imperatively via logsApi.fetchPage to enable client-side cache and event-driven invalidation

    connectedCallback() {
        this.loadInitialData();
        this.initEventChannel();
    }

    disconnectedCallback() {
        this.unsubscribeFromEvents();
    }

    loadInitialData() {
        this.isLoading = true;
        this.currentPage = 1;
        this.refreshTrigger = this.refreshTrigger + 1;
        this.fetchAndSetLogs({ append: false })
            .catch(error => {
                this.showError('Error refreshing data', this.resolveErrorMessage(error));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

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

    handleRefresh() {
        this.loadInitialData();
    }

    handleTableAction(event) {
        const { name, id } = event.detail;
        if (name === 'view_details') {
            this.loadAndDisplayDetails(id);
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
                search: this.searchValue,
                fromOccurredAt: this.fromOccurredAt,
                toOccurredAt: this.toOccurredAt,
                lastOccurredAt: lastRecord?.OccurredAt__c,
                lastId: lastRecord?.Id,
                correlationId: this.correlationId,
                observationType: this.observationType,
                integrationCode: this.integrationCode
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

    handleCloseDetailDrawer() {
        this.showDetailDrawer = false;
        this.selectedRecord = null;
    }

    async fetchAndSetLogs({ append = false, force = false } = {}) {
        this.isLoading = true;
        try {
            const lastRecord = append && this.logs.length ? this.logs[this.logs.length - 1] : null;
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

    refreshSummaries() {
        if (this.wiredSummariesResult) {
            return refreshApex(this.wiredSummariesResult);
        }
        return Promise.resolve();
    }

    async initEventChannel() {
        if (!isEmpEnabled()) {
            return;
        }
        try {
            this.eventChannelName = await getEventChannel();
            this.subscribeToEvents();
        } catch (error) {
            this.showError('Error resolving event channel', this.resolveErrorMessage(error));
        }
    }

    subscribeToEvents() {
        if (!this.eventChannelName || !isEmpEnabled()) {
            return;
        }

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

    get totalEvents() {
        if (!this.summariesData) {
            return 0;
        }
        return this.summariesData.reduce((acc, curr) => acc + (curr.totalEvents || 0), 0);
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

    get maxSummaryEvents() {
        const data = this.summariesData;
        if (!data || !data.length) {
            return 1;
        }
        return data.reduce((max, entry) => Math.max(max, entry.totalEvents || 0), 1);
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
        const detail = event.detail || {};
        const normalizedContext = detail.normalizedContext;
        const fallbackTerm = detail.displayName || detail.integrationCode || '';
        this.searchValue = normalizedContext || fallbackTerm;
        this.integrationCode = '';
        this.loadInitialData();
        this.activeTab = 'filters';
    }
}