import { LightningElement, api } from "lwc";
import {
  formatTime,
  parseNumericInput,
  calcAngle,
  getValueFromAngle,
  getAngleFromPosition,
  getDistanceFromCenter,
  getPositionFromAngle
} from "c/timeClockUtils";

const MINUTE_INTERVALS = 12;

export default class TimeClockPicker extends LightningElement {
  @api label = "Time";
  @api variant = "standard";
  @api required = false;
  @api disabled = false;
  @api hourMode = 24;

  _value = "";

  // UI State
  showPopover = false;
  stage = "hour";
  hour24 = 0;
  minute = 0;

  // Drag State
  isDragging = false;
  dragValue = null;

  // Dimension Cache (Performance)
  faceDiameter = 0;
  // We cache face rect for drag calculations
  _faceRect = null;

  validity = { valid: true, valueMissing: false, badInput: false };
  popoverClass = "slds-popover slds-nubbin_top-right tcp-popover-custom";

  get labelClass() {
    return this.variant === "label-hidden"
      ? "slds-form-element__label slds-assistive-text"
      : "slds-form-element__label";
  }

  @api
  get value() {
    return this._value;
  }

  set value(val) {
    this.syncFromValue(val);
  }

  connectedCallback() {
    if (!this._value) {
      this._value = "00:00";
    }
    this.syncFromValue(this._value);
  }

  disconnectedCallback() {
    document.removeEventListener("mousemove", this.handleGlobalMouseMove);
    document.removeEventListener("mouseup", this.handleGlobalMouseUp);
  }

  renderedCallback() {
    if (this.showPopover && !this.faceDiameter) {
      this.measureFace();
    }
  }

  measureFace() {
    const faceEl = this.template.querySelector(".tcp-face");
    if (faceEl) {
      const rect = faceEl.getBoundingClientRect();
      this.faceDiameter = Math.round(rect.width);
      this._faceRect = rect;
    }
  }

  get displayValue() {
    if (!this._value || this._value === "00:00") return "00:00";
    return formatTime(this.hour24, this.minute);
  }

  get stageLabel() {
    return this.stage === "hour" ? "Select Hour" : "Select Minute";
  }

  get clockFaceClass() {
    let cls = "tcp-face";
    if (Number(this.hourMode) === 24) {
      cls += " tcp-24h-mode";
      if (this.stage === "hour") cls += " tcp-24h-hour-stage";
    }
    return cls;
  }

  get numbers() {
    if (this.stage === "hour") {
      const max = Number(this.hourMode) === 24 ? 24 : 12;
      return Array.from({ length: max }, (_, index) => {
        const number =
          Number(this.hourMode) === 24 ? index : index === 0 ? 12 : index;
        return this.buildNumber(number, "hour");
      });
    }
    return Array.from({ length: MINUTE_INTERVALS }, (_, index) =>
      this.buildNumber(index * 5, "minute")
    );
  }

  buildNumber(value, type) {
    const selected =
      type === "hour" ? this.isHourSelected(value) : this.minute === value;
    const isActive = type === this.stage;

    let maxRadiusPercent = 42; // default outer
    let isInnerHour = false;

    if (type === "hour" && Number(this.hourMode) === 24) {
      if (value >= 1 && value <= 12) {
        maxRadiusPercent = 43;
      } else {
        maxRadiusPercent = 26; // Inner ring
        isInnerHour = true;
      }
    }

    const angle = calcAngle(value, type, this.hourMode);
    const { x, y } = getPositionFromAngle(angle, maxRadiusPercent); // utility

    let className = selected ? "tcp-dot tcp-selected" : "tcp-dot";
    if (isInnerHour) className += " tcp-inner-hour";

    if (Number(this.hourMode) === 24 && type === "hour") {
      className += " tcp-24h-dot";
    }

    if (isActive) {
      className += " tcp-stage-active";
    } else {
      className += " tcp-stage-inactive";
    }

    return {
      value,
      label:
        type === "hour" && this.hourMode === 24
          ? String(value).padStart(2, "0")
          : value,
      className,
      style: `left:${x}%; top:${y}%;`,
      isSelected: selected
    };
  }

  get TargetRadiusPercent() {
    // Current target value
    const val =
      this.isDragging && this.dragValue !== null
        ? this.dragValue
        : this.stage === "hour"
          ? this.displayHourNumber()
          : this.minute;

    if (this.stage === "minute") return 42;
    if (Number(this.hourMode) === 24) {
      // 00:00 (0) is outer (12 pos). 1-12 outer. 13-23 inner.
      // Wait, standard 24h clock: 13-24 outer?
      // TimeClockPicker legacy: 1-12 outer (43), 0 & 13-23 inner (26)?
      // Let's re-read legacy buildNumber:
      // if (value >= 1 && value <= 12) -> maxRadius 43 (Outer). Else 26 (Inner).
      // So 0 is inner. 13-23 is inner.
      if (val >= 1 && val <= 12) return 43;
      return 26;
    }
    return 42;
  }

  isHourSelected(value) {
    if (Number(this.hourMode) === 24) return this.hour24 === value;
    const normalized = this.hour24 % 12 === 0 ? 12 : this.hour24 % 12;
    return normalized === value;
  }

  get isAm() {
    return this.hour24 < 12;
  }
  get isPm() {
    return this.hour24 >= 12;
  }
  get is12HourMode() {
    return Number(this.hourMode) !== 24;
  }

  get amButtonClass() {
    const base = "slds-button slds-button_neutral";
    return this.hour24 < 12 ? "slds-button slds-button_brand" : base;
  }

  get pmButtonClass() {
    const base = "slds-button slds-button_neutral";
    return this.hour24 >= 12 ? "slds-button slds-button_brand" : base;
  }

  // State for smooth rotation
  _totalRotation = 0;

  // PERFORMANCE FIX: Purely reactive, no DOM queries
  get handStyle() {
    const type = this.stage;
    let targetValue;

    if (this.isDragging && this.dragValue !== null) {
      targetValue = this.dragValue;
    } else {
      targetValue = type === "hour" ? this.displayHourNumber() : this.minute;
    }

    const rawTargetAngle = calcAngle(targetValue, type, this.hourMode);

    // Shortest path logic
    let currentMod = this._totalRotation % 360;
    if (currentMod < 0) currentMod += 360;

    let diff = rawTargetAngle - currentMod;
    if (diff < -180) diff += 360;
    if (diff > 180) diff -= 360;

    this._totalRotation += diff;

    const targetPercent = this.TargetRadiusPercent;

    let handHeightStr = "";
    if (this.faceDiameter) {
      const distPx = this.faceDiameter * (targetPercent / 100);
      const padding = 6;
      const h = Math.max(10, Math.round(distPx - padding));
      handHeightStr = `height:${h}px;`;
    } else {
      handHeightStr = `height:${targetPercent}%;`;
    }

    return `${handHeightStr} transform: translateX(-50%) rotate(${this._totalRotation}deg); transition: transform 0.2s cubic-bezier(0.4, 0.0, 0.2, 1);`;
  }

  displayHourNumber() {
    if (Number(this.hourMode) === 24) return this.hour24;
    const normalized = this.hour24 % 12;
    return normalized === 0 ? 12 : normalized;
  }

  // Interactions
  handleFaceMouseDown = (event) => {
    if (this.disabled) return;
    event.preventDefault();

    this.measureFace(); // Ensure we have latest rect
    this.isDragging = true;
    this.updateDragValue(event.clientX, event.clientY);

    // Use arrow functions for bindings to keep 'this' context
    document.addEventListener("mousemove", this.handleGlobalMouseMove);
    document.addEventListener("mouseup", this.handleGlobalMouseUp);
  };

  handleGlobalMouseMove = (event) => {
    if (this.isDragging) {
      // Throttle via requestAnimationFrame if needed, but for now direct update
      this.updateDragValue(event.clientX, event.clientY);
    }
  };

  handleGlobalMouseUp = () => {
    if (this.isDragging) {
      this.isDragging = false;
      this.commitDragValue();
      document.removeEventListener("mousemove", this.handleGlobalMouseMove);
      document.removeEventListener("mouseup", this.handleGlobalMouseUp);
    }
  };

  updateDragValue(x, y) {
    if (!this._faceRect) return;
    const angle = getAngleFromPosition(x, y, this._faceRect);
    const distance = getDistanceFromCenter(x, y, this._faceRect);
    this.dragValue = getValueFromAngle(
      angle,
      this.stage,
      this.hourMode,
      distance,
      this.faceDiameter
    );
  }

  commitDragValue() {
    if (this.dragValue === null) return;
    if (this.stage === "hour") {
      this.setHour(this.dragValue);
      this._value = formatTime(this.hour24, this.minute);
      this.stage = "minute";
    } else {
      this.minute = this.dragValue;
      this._value = formatTime(this.hour24, this.minute);
    }
    this.dragValue = null;
  }

  togglePopover = () => {
    if (this.disabled) return;

    if (!this.showPopover) {
      this.calculatePlacement();
      this.syncFromValue(this._value);
    }

    this.showPopover = !this.showPopover;

    if (this.showPopover) {
      this.stage = "hour";
      // Wait for render to focus and measure
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        const closeBtn = this.template.querySelector(".popover-close-btn");
        if (closeBtn) closeBtn.focus();
        this.measureFace();
      }, 50);
    }
  };

  closePopover = () => {
    this.showPopover = false;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
      const input = this.template.querySelector("input");
      if (input) input.focus();
    }, 0);
  };

  handleInputBlur = () => {
    this.updateValidity();
  };

  calculatePlacement() {
    const inputWrapper = this.template.querySelector(
      ".slds-form-element__control"
    );
    if (!inputWrapper) return;
    const rect = inputWrapper.getBoundingClientRect();
    const popoverHeight = 450;
    const viewportHeight = window.innerHeight;
    const shouldFlip = viewportHeight - rect.bottom < popoverHeight;
    if (shouldFlip) {
      this.popoverClass =
        "slds-popover slds-nubbin_bottom-right tcp-popover-custom tcp-flip-up";
    } else {
      this.popoverClass =
        "slds-popover slds-nubbin_top-right tcp-popover-custom";
    }
  }

  handleFaceClick = (event) => {
    if (this.isDragging) return;
    const val = Number(event.currentTarget.dataset.value);

    if (this.stage === "hour") {
      this.setHour(val);
      this._value = formatTime(this.hour24, this.minute);
      this.stage = "minute";
      return;
    }
    this.minute = val;
    this._value = formatTime(this.hour24, this.minute);
  };

  handleMeridianToggle(event) {
    event.stopPropagation();
    event.preventDefault();

    if (!this.is12HourMode) return;
    const shouldBePm = event.currentTarget.dataset.value === "PM";

    const normalized = this.hour24 % 12;
    this.hour24 = shouldBePm ? normalized + 12 : normalized;
    this._value = formatTime(this.hour24, this.minute);
  }

  setHour(value) {
    if (Number(this.hourMode) === 24) {
      this.hour24 = value;
      return;
    }
    const normalized = value === 12 ? 0 : value;
    this.hour24 = this.hour24 >= 12 ? (normalized + 12) % 24 : normalized;
  }

  setNow = () => {
    const now = new Date();
    this.hour24 = now.getHours();
    this.minute = Math.floor(now.getMinutes() / 5) * 5;
    this.stage = "minute";
    this.apply();
  };

  clearValue = () => {
    this.hour24 = 0;
    this.minute = 0;
    this._value = "";
    this.stage = "hour";
    this.dispatchChange("");
    this.closePopover();
  };

  apply = () => {
    const formatted = formatTime(this.hour24, this.minute);
    this._value = formatted;
    this.dispatchChange(formatted);
    this.closePopover();
  };

  dispatchChange(value) {
    this.dispatchEvent(
      new CustomEvent("change", {
        detail: { value },
        bubbles: true,
        composed: true
      })
    );
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") {
      this.closePopover();
      return;
    }

    if (event.key === " ") {
      event.preventDefault();
      if (!this.showPopover) {
        this.togglePopover();
      } else if (this.stage === "hour") {
        this.stage = "minute";
      } else {
        this.apply();
      }
      return;
    }

    if (event.key === "Enter") {
      if (this.showPopover) {
        this.apply();
      } else {
        this.handleInputCommit();
      }
      return;
    }

    if (this.showPopover) {
      const isArrowKey = [
        "ArrowUp",
        "ArrowDown",
        "ArrowLeft",
        "ArrowRight"
      ].includes(event.key);
      if (isArrowKey) {
        event.preventDefault();
        if (this.stage === "hour") {
          this.handleHourArrowKeys(event.key);
        } else {
          this.handleMinuteArrowKeys(event.key);
        }
      }
      if (event.key === "Tab") {
        this.trapFocus(event);
      }
    }
  };

  // ... [Refactoring note: trapFocus, arrow keys kept similar but accessing this.hour24 directly]
  trapFocus(event) {
    // (Existing logic kept for brevity/minimizing unrelated drift)
    if (!this.showPopover) return;
    const popoverEl = this.template.querySelector(".slds-popover");
    if (!popoverEl) return;
    const allFocusables = Array.from(
      popoverEl.querySelectorAll(
        'button, lightning-button-icon, [tabindex="0"]'
      )
    ).filter(
      (el) =>
        (el.offsetWidth > 0 || el.offsetHeight > 0) &&
        typeof el.focus === "function"
    );
    if (allFocusables.length === 0) return;
    const first = allFocusables[0];
    const last = allFocusables[allFocusables.length - 1];
    const active = this.template.activeElement;

    if (event.shiftKey) {
      if (active === first || !popoverEl.contains(active)) {
        last.focus();
        event.preventDefault();
      }
    } else {
      if (active === last || !popoverEl.contains(active)) {
        first.focus();
        event.preventDefault();
      }
    }
  }

  handleHourArrowKeys(key) {
    let current = this.hour24;
    if (key === "ArrowUp" || key === "ArrowRight") current = (current + 1) % 24;
    else current = (current - 1 + 24) % 24;

    this.hour24 = current;
    this.dragValue = null;
    this._value = formatTime(this.hour24, this.minute);
  }

  handleMinuteArrowKeys(key) {
    let current = this.minute;
    if (key === "ArrowUp" || key === "ArrowRight") current = (current + 5) % 60;
    else current = (current - 5 + 60) % 60;

    this.minute = current;
    this.dragValue = null;
    this._value = formatTime(this.hour24, this.minute);
  }

  handleInputChange = (event) => {
    const inputValue = event.target.value.replace(/\D/g, "");
    // We just parse and if valid update internal
    const result = parseNumericInput(inputValue, this.hourMode);
    if (result) {
      this.hour24 = result.hours;
      this.minute = result.minutes;
      this.validity.badInput = false;
    } else if (result === null) {
      // clear
      this.hour24 = 0;
      this.minute = 0;
      this.validity.badInput = false;
    } else {
      this.validity.badInput = true;
    }
  };

  handleInputCommit() {
    if (this.validity.badInput) {
      this.reportValidity();
    } else {
      this.apply();
    }
  }

  syncFromValue(value) {
    this._value = value || "00:00";
    if (!value) {
      this.hour24 = 0;
      this.minute = 0;
      return;
    }
    const parts = value.split(":");
    if (parts.length < 2) return;

    let hh = parseInt(parts[0], 10);
    let mm = parseInt(parts[1], 10);

    if (!isNaN(hh)) this.hour24 = Math.min(23, Math.max(0, hh));
    if (!isNaN(mm)) this.minute = Math.min(59, Math.max(0, mm));
  }

  @api
  checkValidity() {
    this.updateValidity();
    return this.validity.valid;
  }

  @api
  reportValidity() {
    this.updateValidity();
    if (!this.validity.valid) {
      const input = this.template.querySelector("input");
      if (input) {
        input.setCustomValidity(this.getValidationMessage());
        input.reportValidity();
      }
    }
    return this.validity.valid;
  }

  updateValidity() {
    this.validity.valueMissing = this.required && !this._value;
    this.validity.valid =
      !this.validity.valueMissing && !this.validity.badInput;
  }

  getValidationMessage() {
    if (this.validity.valueMissing) return "Complete this field.";
    if (this.validity.badInput) return "Enter a valid time.";
    return "";
  }
}
