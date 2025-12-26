import { LightningElement, api, wire, track } from 'lwc';
import getFilterOptions from '@salesforce/apex/IntegrationHealthController.getFilterOptions';

export default class IhdFilters extends LightningElement {
    @api lastUpdated;
    @api isLoading = false;    
    @track showFilters = false;

    _searchValue = '';
    _observationValue = '';
    _integrationCodeValue = '';
    _correlationValue = '';
    _fromUTC = '';
    _toUTC = '';
    _fromDate = '';
    _fromTime = '';
    _toDate = '';
    _toTime = '';

    observationOptions = [];
    integrationOptions = [];

    @wire(getFilterOptions)
    wiredOptions({ error, data }) {
        if (data) {
            this.observationOptions = [
                { label: 'All Types', value: '' },
                ...data.observationTypes.map(type => ({ label: type, value: type }))
            ];
            this.integrationOptions = [
                { label: 'All Integrations', value: '' },
                ...data.integrationCodes.map(code => ({ label: code, value: code }))
            ];
        }
    }
    
    @api get searchValue() { return this._searchValue; }
    set searchValue(value) { this._searchValue = value || ''; }
    
    @api get correlationValue() { return this._correlationValue; }
    set correlationValue(value) { this._correlationValue = value || ''; }
    
    @api get observationValue() { return this._observationValue; }
    set observationValue(value) { this._observationValue = value || ''; }

    @api get integrationCodeValue() { return this._integrationCodeValue; }
    set integrationCodeValue(value) { this._integrationCodeValue = value || ''; }

    @api get fromValue() { return this._fromUTC; }
    set fromValue(value) { this._fromUTC = value || ''; this.syncFromLocalValue(); }

    @api get toValue() { return this._toUTC; }
    set toValue(value) { this._toUTC = value || ''; this.syncToLocalValue(); }
    
    get fromDate() { return this._fromDate; }
    get toDate() { return this._toDate; }
    get fromTime() { return this._fromTime; }
    get toTime() { return this._toTime; }

    handleToggleFilters() {
        this.showFilters = !this.showFilters;
    }

    get filterIcon() {
        return this.showFilters ? 'utility:close' : 'utility:filterList';
    }

    get filterButtonVariant() {
        return this.showFilters ? 'brand' : 'neutral';
    }

    handleSearchChange(event) {
        this._searchValue = event.detail.value;
        this.debounceFilter();
    }

    handleObservationChange(event) {
        this._observationValue = event.detail.value;
        this.dispatchFiltersChanged();
    }

    handleIntegrationChange(event) {
        this._integrationCodeValue = event.detail.value;
        this.dispatchFiltersChanged();
    }

    handleCorrelationChange(event) {
        this._correlationValue = event.detail.value;
        this.debounceFilter();
    }

    handleFromDateChange(event) {
        this._fromDate = event.detail.value || '';
        this.updateFromUTCFromParts();
    }

    handleFromTimeChange(event) {
        this._fromTime = event.detail?.value || '';
        this.updateFromUTCFromParts();
    }

    handleToDateChange(event) {
        this._toDate = event.detail.value || '';
        this.updateToUTCFromParts();
    }

    handleToTimeChange(event) {
        this._toTime = event.detail?.value || '';
        this.updateToUTCFromParts();
    }

    handleRefresh() {
        this.dispatchEvent(new CustomEvent('refresh'));
    }

    handleClearFilters() {
        this._searchValue = '';
        this._observationValue = '';
        this._integrationCodeValue = '';
        this._correlationValue = '';
        this._fromUTC = '';
        this._toUTC = '';
        this._fromDate = '';
        this._fromTime = '';
        this._toDate = '';
        this._toTime = '';
        this.dispatchFiltersChanged();
    }

    filterTimeout;
    debounceFilter() {
        window.clearTimeout(this.filterTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.filterTimeout = window.setTimeout(() => {
            this.dispatchFiltersChanged();
        }, 400);
    }

    updateFromUTCFromParts() {
        this._fromUTC = this.convertLocalPartsToUTC(this._fromDate, this._fromTime);
        this.dispatchFiltersChanged();
    }

    updateToUTCFromParts() {
        this._toUTC = this.convertLocalPartsToUTC(this._toDate, this._toTime);
        this.dispatchFiltersChanged();
    }

    dispatchFiltersChanged() {
        const filters = {
            search: this._searchValue,
            observationType: this._observationValue,
            integrationCode: this._integrationCodeValue,
            correlationId: this._correlationValue,
            from: this._fromUTC,
            to: this._toUTC
        };
        this.dispatchEvent(new CustomEvent('filterschanged', { detail: filters }));
    }

    convertLocalPartsToUTC(datePart, timePart) {
        if (!datePart || !timePart) return '';
        const parsed = new Date(`${datePart}T${timePart}`);
        if (isNaN(parsed.getTime())) return '';
        return parsed.toISOString();
    }

    syncFromLocalValue() {
        if (!this._fromUTC) { this._fromDate = ''; this._fromTime = ''; return; }
        const local = new Date(this._fromUTC);
        if (isNaN(local.getTime())) { this._fromDate = ''; this._fromTime = ''; return; }
        this._fromDate = this.buildLocalDate(local);
        this._fromTime = this.buildLocalTime(local);
    }

    syncToLocalValue() {
        if (!this._toUTC) { this._toDate = ''; this._toTime = ''; return; }
        const local = new Date(this._toUTC);
        if (isNaN(local.getTime())) { this._toDate = ''; this._toTime = ''; return; }
        this._toDate = this.buildLocalDate(local);
        this._toTime = this.buildLocalTime(local);
    }

    buildLocalDate(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    buildLocalTime(date) {
        const hour = String(date.getHours()).padStart(2, '0');
        const minute = String(date.getMinutes()).padStart(2, '0');
        return `${hour}:${minute}`;
    }
}