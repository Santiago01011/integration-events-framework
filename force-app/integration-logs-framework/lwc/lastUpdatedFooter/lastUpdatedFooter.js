import { LightningElement, api } from 'lwc';

export default class LastUpdatedFooter extends LightningElement {
    @api lastUpdated;
    @api isLoading = false;
    /** TTL in milliseconds to consider data stale (default 60s) */
    @api ttlMs = 60000;

    _now = Date.now();
    _timer;

    connectedCallback() {
        // keep a lightweight interval to refresh staleness UI
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._timer = setInterval(() => {
            this._now = Date.now();
        }, 5000);
    }

    disconnectedCallback() {
        if (this._timer) {
            clearInterval(this._timer);
            this._timer = null;
        }
    }

    get isStale() {
        if (!this.lastUpdated) return false;
        const ts = Date.parse(this.lastUpdated);
        if (isNaN(ts)) return false;
        return (this._now - ts) > (this.ttlMs || 60000);
    }

    get staleLabel() {
        return this.isStale ? 'Data may be stale' : 'Up to date';
    }

    handleRefresh() {
        this.dispatchEvent(new CustomEvent('refresh'));
    }
}