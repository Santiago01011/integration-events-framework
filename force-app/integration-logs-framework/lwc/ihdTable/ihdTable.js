import { LightningElement, api } from "lwc";

/**
 * @description A generic, reusable Salesforce Datatable wrapper.
 * completely agnostic of the data it displays.
 */
export default class IhdTable extends LightningElement {
  /**
   * @description The unique identifier field for rows.
   */
  @api keyField = "Id";

  /**
   * @description The data rows to display.
   */
  @api rows = [];

  /**
   * @description The height of the table container (e.g., '600px', 'auto').
   */
  @api tableHeight;

  /**
   * @description The column definitions (standard lightning-datatable format).
   */
  @api columns = [];

  /**
   * @description Whether the table is loading data.
   */
  @api isLoading = false;

  /**
   * @description Enables infinite loading features.
   */
  @api enableInfiniteLoading = false;

  /**
   * @description The field name currently sorted by.
   */
  @api sortedBy;

  /**
   * @description The sort direction ('asc' or 'desc').
   */
  @api sortedDirection;

  /**
   * @description Message to show when no rows are present.
   */
  @api noDataMessage = "No items found.";

  /**
   * @description Title for the empty state illustration.
   */
  @api emptyStateTitle = "";

  /**
   * @description Message for the empty state illustration.
   */
  @api emptyStateMessage = "";

  /**
   * @description Icon name for the empty state illustration.
   */
  @api emptyStateIcon = "utility:empty";

  /**
   * @description Local loading lock to prevent race conditions with prop updates.
   */
  _loadingLock = false;

  // --- Getters ---

  get hasRows() {
    return Array.isArray(this.rows) && this.rows.length > 0;
  }

  get showEmptyState() {
    return !this.isLoading && !this.hasRows;
  }

  get computedEmptyStateTitle() {
    return this.emptyStateTitle || this.noDataMessage;
  }

  get computedEmptyStateMessage() {
    return this.emptyStateMessage || "";
  }

  get wrapperStyle() {
    return this.tableHeight ? `height: ${this.tableHeight};` : "";
  }

  handleRowAction(event) {
    this.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: event.detail
      })
    );
  }

  handleSort(event) {
    this.dispatchEvent(
      new CustomEvent("sort", {
        detail: {
          fieldName: event.detail.fieldName,
          sortDirection: event.detail.sortDirection
        }
      })
    );
  }

  /**
   * @description Handles the loadmore event from lightning-datatable.
   * Uses a local loading lock to prevent race conditions between event firing
   * and parent component prop updates.
   */
  handleLoadMore() {
    if (this._loadingLock || this.isLoading || !this.enableInfiniteLoading) {
      return;
    }
    this._loadingLock = true;
    this.dispatchEvent(new CustomEvent("loadmore"));
  }

  /**
   * @description Watches the isLoading prop to clear the loading lock.
   */
  renderedCallback() {
    if (!this.isLoading && this._loadingLock) {
      this._loadingLock = false;
    }
  }
}
