import { LightningElement, api } from "lwc";

import IEF_Last_Updated from "@salesforce/label/c.IEF_Last_Updated";
import IEF_Refresh_Data from "@salesforce/label/c.IEF_Refresh_Data";

export default class IefLastUpdatedFooter extends LightningElement {
  labels = {
    IEF_Last_Updated,
    IEF_Refresh_Data
  };
  @api lastUpdated;
  @api isLoading = false;
  @api ttlMs = 60000;

  _now = Date.now();
  _timer;

  connectedCallback() {
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
    return this._now - ts > (this.ttlMs || 60000);
  }

  get staleLabel() {
    return this.isStale ? "Data may be stale" : "Up to date";
  }

  handleRefresh() {
    this.dispatchEvent(new CustomEvent("refresh"));
  }
}
