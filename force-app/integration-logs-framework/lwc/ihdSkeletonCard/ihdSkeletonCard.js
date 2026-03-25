import { LightningElement, api } from "lwc";

/**
 * @description Reusable skeleton loader component with CSS shimmer animation.
 * Renders different placeholder shapes based on the variant prop to indicate
 * the type of content being loaded.
 */
export default class IhdSkeletonCard extends LightningElement {
  /**
   * @description The skeleton variant to render.
   * Options: 'donut', 'list', 'sparkline'
   * @type {string}
   */
  @api variant = "donut";

  /** @returns {boolean} True if variant is 'donut' */
  get isDonut() {
    return this.variant === "donut";
  }

  /** @returns {boolean} True if variant is 'list' */
  get isList() {
    return this.variant === "list";
  }

  /** @returns {boolean} True if variant is 'sparkline' */
  get isSparkline() {
    return this.variant === "sparkline";
  }
}
