import { LightningElement, api } from "lwc";
import logsApi from "c/utilsLogsApi";

/**
 * @description Headless component that manages real-time event subscriptions,
 * coalescing multiple events into a single update to the UI.
 */
export default class IhdEventHub extends LightningElement {
  /**
   * @description Map of observation types to severity levels.
   */
  @api typeToSeverity = {};

  /**
   * @description List of integration summaries used for context normalization.
   */
  @api summaries = [];

  /**
   * @description Delay in milliseconds to wait before flushing queued events.
   */
  @api coalesceMs = 2000;

  _pendingEvents = [];
  _flushTimer = null;
  _staleInactivityTimer = null;
  _staleMaxAgeTimer = null;
  _isStale = false;

  STALE_INACTIVITY_MS = 15 * 60 * 1000; // 15 minutes no events
  STALE_MAX_AGE_MS = 30 * 60 * 1000; // 30 minutes total age

  connectedCallback() {
    this._initLiveConnection();
  }

  disconnectedCallback() {
    logsApi.unsubscribeFromLogs(this);
    this._clearStaleTimers();
    this._notifyStatus(false, false);
  }

  /**
   * @description Initializes the EMP API connection.
   */
  async _initLiveConnection() {
    try {
      await logsApi.initRealtime(this, (payload) => {
        this._handleNewEvent(payload);
      });
      this.refresh();
    } catch (error) {
      this._notifyStatus(false, false);
      console.warn("IHD Event Hub: Connection failed", error);
    }
  }

  /**
   * @description Resets the stale timers and status.
   * Exposed so parent can manually refresh logic.
   */
  @api
  refresh() {
    this._isStale = false;
    this._clearStaleTimers();
    this._startMaxAgeTimer();
    this._resetInactivityTimer();
    this._notifyStatus(true, false);
  }

  /**
   * @description Queues a new event and schedules a flush.
   */
  _handleNewEvent(payload) {
    if (!this._isStale) {
      this._resetInactivityTimer();
    }

    this._pendingEvents.push(payload);
    if (this._flushTimer) return;

    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._flushTimer = setTimeout(() => {
      this._flushEvents();
    }, this.coalesceMs);
  }

  /**
   * @description Processes queued events, transforms them to rows, and notifies parent.
   */
  _flushEvents() {
    const rows = this._pendingEvents
      .splice(0)
      .map((e) =>
        logsApi.transformEventToRow(e, this.typeToSeverity, (c) =>
          this._getNormalizedContext(c)
        )
      );
    this._flushTimer = null;
    if (!rows.length) return;

    if (rows.length === 1) {
      const r = rows[0];
      const variant = r.statusIconName.split(":").pop().replace("help", "info");
      logsApi.showToast(
        this,
        "New integration event",
        r.IntegrationCode__c,
        variant
      );
    } else {
      logsApi.showToast(
        this,
        "IHD Pulse",
        `${rows.length} integration events received`,
        "info"
      );
    }

    this.dispatchEvent(new CustomEvent("newrows", { detail: rows }));
    this.dispatchEvent(new CustomEvent("activity"));
  }

  /**
   * @description Resolves friendly name for integration code using local summaries.
   */
  _getNormalizedContext(integrationCode) {
    if (!this.summaries || !integrationCode) return integrationCode;
    const match = this.summaries.find(
      (s) => s.integrationCode === integrationCode
    );
    if (match) {
      return match.groupName || match.displayName || integrationCode;
    }
    return integrationCode;
  }

  /**
   * @description Dispatches status change event.
   */
  _notifyStatus(isConnected, isStale) {
    this.dispatchEvent(
      new CustomEvent("statuschange", {
        detail: { isConnected, isStale }
      })
    );
  }

  _clearStaleTimers() {
    if (this._staleInactivityTimer) clearTimeout(this._staleInactivityTimer);
    if (this._staleMaxAgeTimer) clearTimeout(this._staleMaxAgeTimer);
  }

  _startMaxAgeTimer() {
    if (this._staleMaxAgeTimer) clearTimeout(this._staleMaxAgeTimer);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._staleMaxAgeTimer = setTimeout(() => {
      this._markAsStale();
    }, this.STALE_MAX_AGE_MS);
  }

  _resetInactivityTimer() {
    if (this._staleInactivityTimer) clearTimeout(this._staleInactivityTimer);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._staleInactivityTimer = setTimeout(() => {
      this._markAsStale();
    }, this.STALE_INACTIVITY_MS);
  }

  _markAsStale() {
    if (this._isStale) return;
    this._isStale = true;
    this._notifyStatus(true, true);
  }
}
