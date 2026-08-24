import { LightningElement, api } from "lwc";

/**
 * @description A reusable progress bar component that displays success and error percentages.
 * Can be used independently or within other components.
 */
export default class IefProgressBar extends LightningElement {
  /**
   * @description The percentage of success, from 0 to 100.
   * @type {number}
   */
  _successPercentage = 0;

  /**
   * @description The percentage of error, from 0 to 100.
   * @type {number}
   */
  _errorPercentage = 0;

  /**
   * @description Optional label to display above the progress bar.
   * @type {string}
   */
  @api label = "";

  @api
  get successPercentage() {
    return this._successPercentage;
  }
  set successPercentage(value) {
    this._successPercentage = value;
    this.updateIefProgressBar();
  }

  @api
  get errorPercentage() {
    return this._errorPercentage;
  }
  set errorPercentage(value) {
    this._errorPercentage = value;
    this.updateIefProgressBar();
  }

  renderedCallback() {
    this.updateIefProgressBar();
  }

  updateIefProgressBar() {
    const successBar = this.template.querySelector(
      '[data-testid="success-bar"]'
    );
    const errorBar = this.template.querySelector('[data-testid="error-bar"]');

    if (successBar) {
      successBar.style.width = `${this._successPercentage}%`;
    }
    if (errorBar) {
      errorBar.style.width = `${this._errorPercentage}%`;
    }
  }
}
