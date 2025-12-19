import { LightningElement, api } from 'lwc';

export default class IhdFilters extends LightningElement {
    @api statusValue = 'All';
    @api searchValue = '';

    get statusOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Error', value: 'Error' },
            { label: 'Processed', value: 'Processed' }
        ];
    }

    handleStatusChange(event) {
        const errorStatus = event.detail.value;
        this.dispatchEvent(new CustomEvent('statuschange', {
            detail: { value: errorStatus }
        }));
    }

    handleSearchChange(event) {
        const errorSearch = event.detail.value;
        this.dispatchEvent(new CustomEvent('searchchange', {
            detail: { value: errorSearch }
        }));
    }

    handleClearFilters() {
        this.dispatchEvent(new CustomEvent('clearfilters'));
    }
}