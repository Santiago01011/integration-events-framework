import { LightningElement, api } from "lwc";
import logsApi from "c/utilsLogsApi";

// Custom Labels
import IEF_General_Information from "@salesforce/label/c.IEF_General_Information";
import IEF_Occurred_At from "@salesforce/label/c.IEF_Occurred_At";
import IEF_Integration_Code from "@salesforce/label/c.IEF_Integration_Code";
import IEF_Observation_Type from "@salesforce/label/c.IEF_Observation_Type";
import IEF_Correlation_Id from "@salesforce/label/c.IEF_Correlation_Id";
import IEF_Log_Payload from "@salesforce/label/c.IEF_Log_Payload";
import IEF_Copy_JSON from "@salesforce/label/c.IEF_Copy_JSON";
import IEF_Close from "@salesforce/label/c.IEF_Close";
import IEF_Copied_Success from "@salesforce/label/c.IEF_Copied_Success";

export default class IefDetailDrawer extends LightningElement {
  // Expose labels for template binding
  labels = {
    IEF_General_Information,
    IEF_Occurred_At,
    IEF_Integration_Code,
    IEF_Observation_Type,
    IEF_Correlation_Id,
    IEF_Log_Payload,
    IEF_Copy_JSON,
    IEF_Close,
    IEF_Copied_Success
  };
  @api visible = false;
  @api record;
  _initialFocusSet = false;
  _previousFocusElement = null;

  /**
   * @description Gets the list of focusable elements within the drawer.
   * @returns {Element[]} Array of focusable elements
   */
  get focusableElements() {
    const selector = [
      "button:not([disabled])",
      "input:not([disabled])",
      "select:not([disabled])",
      "textarea:not([disabled])",
      "a[href]",
      "[tabindex]:not([tabindex='-1'])"
    ].join(",");
    return Array.from(this.template.querySelectorAll(selector));
  }

  /**
   * @description Gets the first focusable element in the drawer.
   * @returns {Element|null}
   */
  get firstFocusable() {
    const focusables = this.focusableElements;
    return focusables.length > 0 ? focusables[0] : null;
  }

  /**
   * @description Gets the last focusable element in the drawer.
   * @returns {Element|null}
   */
  get lastFocusable() {
    const focusables = this.focusableElements;
    return focusables.length > 0 ? focusables[focusables.length - 1] : null;
  }

  get log() {
    return this.record?.record || {};
  }

  get severity() {
    return this.record?.severity;
  }

  get isError() {
    return this.severity === "ERROR" || this.severity === "FATAL";
  }

  get badgeClass() {
    const base = "slds-badge slds-var-m-left_small";
    if (this.isError) return `${base} slds-theme_error`;
    if (this.severity === "WARN") return `${base} slds-theme_warning`;
    if (this.severity === "SUCCESS") return `${base} slds-theme_success`;
    if (this.severity === "INFO") return `${base} slds-theme_inverse`;
    return `${base}`;
  }

  get messageBoxClass() {
    return this.isError ? "message-box-error" : "message-box-info";
  }

  get messageIcon() {
    if (this.isError) return "utility:error";
    if (this.severity === "WARN") return "utility:warning";
    if (this.severity === "SUCCESS") return "utility:success";
    if (this.severity === "INFO") return "utility:info";
    return "utility:help";
  }

  get formattedContext() {
    const raw = this.log.Context__c || "";
    if (!raw) return "No Payload";

    try {
      let parsed = JSON.parse(raw);
      if (typeof parsed === "string") {
        try {
          parsed = JSON.parse(parsed);
        } catch {
          // Ignored
        }
      }
      return JSON.stringify(parsed, null, 4);
    } catch {
      return raw;
    }
  }

  renderedCallback() {
    if (this.visible && !this._initialFocusSet) {
      // Store the element that had focus before the drawer opened
      this._previousFocusElement = document.activeElement;
      const section = this.template.querySelector("section");
      if (section) {
        section.focus();
        this._initialFocusSet = true;
      }
    } else if (!this.visible) {
      this._initialFocusSet = false;
      // Return focus to the previously focused element
      if (this._previousFocusElement) {
        this._previousFocusElement.focus();
        this._previousFocusElement = null;
      }
    }
  }

  /**
   * @description Handles keyboard events for focus trapping and Escape key.
   * @param {KeyboardEvent} event - The keydown event
   */
  handleKeyDown(event) {
    if (event.key === "Escape") {
      event.stopPropagation();
      this.handleClose();
      return;
    }

    // Focus trap: Tab / Shift+Tab cycling
    if (event.key === "Tab") {
      const focusables = this.focusableElements;
      if (focusables.length === 0) {
        event.preventDefault();
        return;
      }

      const first = this.firstFocusable;
      const last = this.lastFocusable;

      if (event.shiftKey) {
        // Shift+Tab: if on first element, wrap to last
        if (document.activeElement === first) {
          event.preventDefault();
          last.focus();
        }
      } else {
        // Tab: if on last element, wrap to first
        if (document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    }
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleCopy() {
    const text = this.formattedContext;
    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(text);
      logsApi.showToast(
        this,
        "Success",
        "Payload copied to clipboard",
        "success"
      );
    } else {
      logsApi.showError(this, "Error", "Clipboard access denied");
    }
  }
}
