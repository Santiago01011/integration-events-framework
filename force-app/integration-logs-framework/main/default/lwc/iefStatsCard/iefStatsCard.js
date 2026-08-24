import { LightningElement, api, track } from "lwc";

/**
 * @description A reusable stats card component that displays a progress bar and a list of statistics.
 * Supports two variants: 'large' (default) for detailed stats and 'small' for compact tiles.
 */
export default class IefStatsCard extends LightningElement {
  @track _stats = [];

  /**
   * @description The display variant. Options are 'large' (default) or 'small'.
   * @type {string}
   */
  @api variant = "large";

  /**
   * @description The card title or tile label.
   * @type {string}
   */
  @api title = "";

  /**
   * @description The main value to display (primarily used in 'small' variant).
   * @type {string|number}
   */
  @api value = "";

  /**
   * @description Whether the card/tile is currently selected.
   * @type {boolean}
   */
  @api isSelected = false;

  /**
   * @description Whether the card is currently focused via keyboard navigation.
   * @type {boolean}
   */
  @api isFocused = false;

  /**
   * @description Theme for the label text color in 'small' variant.
   * Options: 'success', 'error', or null for default.
   * @type {string}
   */
  @api labelTheme = "";

  /**
   * @description The success percentage (0-100) for the progress bar (Large variant).
   * @type {number}
   */
  @api successPercentage = 0;

  /**
   * @description The error percentage (0-100) for the progress bar (Large variant).
   * @type {number}
   */
  @api errorPercentage = 0;

  /**
   * @description Label for the success bar.
   * @type {string}
   */
  @api successLabel = "Success";

  /**
   * @description Label for the error bar.
   * @type {string}
   */
  @api errorLabel = "Error";

  /**
   * @description Array of stat objects to display (Large variant).
   */
  @api
  get stats() {
    return this._stats;
  }
  set stats(value) {
    if (value) {
      this._stats = value.map((stat) => ({
        ...stat,
        badgeClass: this.getBadgeClass(stat.badgeTheme)
      }));
    } else {
      this._stats = [];
    }
  }

  // --- Getters for Styles ---

  get isSmall() {
    return this.variant === "small";
  }

  get isLarge() {
    return this.variant === "large";
  }

  get containerClass() {
    if (this.isSmall) {
      return `tile-card ${this.isSelected ? "tile-selected" : ""}`;
    }
    return "card-container";
  }

  get labelClass() {
    if (this.labelTheme === "success") return "tile-label status-success";
    if (this.labelTheme === "error") return "tile-label status-error";
    return "tile-label";
  }

  /**
   * @description Generates an accessible label for the stats card based on variant and content.
   * @returns {string} Accessible label describing the card purpose and key stats
   */
  get statsAriaLabel() {
    if (this.isSmall) {
      return `${this.title}: ${this.value}`;
    }
    const statsCount = this._stats ? this._stats.length : 0;
    return `${this.title}, ${statsCount} statistics, ${this.successPercentage}% success rate`;
  }

  // --- Event Handlers ---

  handleCardClick() {
    const cardClickEvent = new CustomEvent("cardclick");
    this.dispatchEvent(cardClickEvent);
  }

  handleKeyDown(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.handleCardClick();
    }
  }

  getBadgeClass(theme) {
    if (!theme) return "";
    const baseClass = "slds-badge";
    if (theme === "success" || theme === "error") {
      return `${baseClass} slds-theme_${theme}`;
    }
    return baseClass;
  }
}
