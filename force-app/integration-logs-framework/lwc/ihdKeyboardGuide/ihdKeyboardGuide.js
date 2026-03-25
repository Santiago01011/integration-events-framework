import { LightningElement, api } from "lwc";

/**
 * @description A modal component that displays keyboard shortcuts for the Integration Health Dashboard.
 */
export default class IhdKeyboardGuide extends LightningElement {
  @api visible = false;

  /**
   * @description Keyboard shortcuts data for display.
   * @returns {Array<{category: string, shortcuts: Array<{key: string, description: string}>}>}
   */
  get shortcutGroups() {
    return [
      {
        category: "Navigation",
        shortcuts: [
          { key: "j / ↓", description: "Navigate to next card" },
          { key: "k / ↑", description: "Navigate to previous card" },
          { key: "Enter / Space", description: "Open selected card" },
          { key: "1-4", description: "Switch tabs" },
          { key: "Esc", description: "Close drawer or modal" }
        ]
      },
      {
        category: "Actions",
        shortcuts: [
          { key: "?", description: "Show this help" },
          { key: "/", description: "Focus search input" },
          { key: "r", description: "Refresh data" }
        ]
      }
    ];
  }

  renderedCallback() {
    if (this.visible) {
      // Focus the close button when modal opens using microtask
      Promise.resolve().then(() => {
        const closeBtn = this.template.querySelector(".close-button");
        if (closeBtn) {
          closeBtn.focus();
        }
      });
    }
  }

  /**
   * @description Handles the close action for the keyboard guide modal.
   */
  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  /**
   * @description Handles keydown events for Escape key support.
   * @param {KeyboardEvent} event - The keydown event
   */
  handleKeyDown(event) {
    if (event.key === "Escape") {
      this.handleClose();
    }
  }
}
