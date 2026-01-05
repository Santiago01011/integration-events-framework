import { LightningElement, api, track } from 'lwc';

const MINUTE_INTERVALS = 12;

export default class TimeClockPicker extends LightningElement {
    @api label = '';
    @api required = false;
    @api disabled = false;
    @api hourMode = 24; // Can be set to 12 or 24 hours

    _value = '';
    _totalRotation = 0;
    
    @track showPopover = false;
    @track stage = 'hour';
    @track hour24 = 0;
    @track minute = 0;
    @track isDragging = false;
    @track dragValue = null;
    @track faceDiameter = 0;
    validity = { valid: true, valueMissing: false, badInput: false };
    popoverClass = 'slds-popover slds-nubbin_top-right tcp-popover-custom';

    @api
    get value() {
        return this._value;
    }

    set value(val) {
        this.syncFromValue(val);
    }

    connectedCallback() {
        if (!this._value) {
            this._value = '00:00';
        }
        this.syncFromValue(this._value);
    }

    renderedCallback() {
        const faceEl = this.template.querySelector('.tcp-face');
        if (!faceEl) return;
        const width = Math.round(faceEl.getBoundingClientRect().width);
        if (width && width !== this.faceDiameter) {
            this.faceDiameter = width;
        }
    }

    get displayValue() {
        if (!this._value || this._value === '00:00') return '00:00';
        return this.formatTime(this.hour24, this.minute);
    }

    get stageLabel() {
        return this.stage === 'hour' ? 'Select Hour' : 'Select Minute';
    }

    get hourStageClass() {
        return this.stage === 'hour' ? 'tcp-stage-active' : 'tcp-stage-inactive';
    }

    get minuteStageClass() {
        return this.stage === 'minute' ? 'tcp-stage-active' : 'tcp-stage-inactive';
    }

    get clockFaceClass() {
        let cls = 'tcp-face';
        if (this.hourMode === 24) {
            cls += ' tcp-24h-mode';
            if (this.stage === 'hour') cls += ' tcp-24h-hour-stage';
        }
        return cls;
    }

    get numbers() {
        if (this.stage === 'hour') {    
            const max = this.hourMode === 24 ? 24 : 12;
            return Array.from({ length: max }, (_, index) => {
                const number = this.hourMode === 24 ? index : (index === 0 ? 12 : index);
                return this.buildNumber(number, 'hour');
            });
        }
        return Array.from({ length: MINUTE_INTERVALS }, (_, index) => this.buildNumber(index * 5, 'minute'));
    }

    buildNumber(value, type) {
        const selected = type === 'hour' ? this.isHourSelected(value) : this.minute === value;
        const isActive = type === this.stage;
        
        let maxRadius;
        let isInnerHour = false;

        if (type === 'hour') {
            if (this.hourMode === 24) {
                if (value >= 1 && value <= 12) {
                    maxRadius = 43; 
                } else {
                    maxRadius = 26;
                    isInnerHour = true;
                }
            } else {
                maxRadius = 42;
            }
        } else {
            maxRadius = 42;
        }
        
        const angle = this.calcAngle(value, type);
        const x = 50 + maxRadius * Math.sin((Math.PI / 180) * angle);
        const y = 50 - maxRadius * Math.cos((Math.PI / 180) * angle);
        
        let className = selected ? 'tcp-dot tcp-selected' : 'tcp-dot';
        if (isInnerHour) className += ' tcp-inner-hour';
        
        if (this.hourMode === 24 && type === 'hour') {
             className += ' tcp-24h-dot';
        }

        if (isActive) {
            className += ' tcp-stage-active';
        } else {
            className += ' tcp-stage-inactive';
        }

        return {
            value,
            label: type === 'hour' && this.hourMode === 24 ? String(value).padStart(2, '0') : value,
            className,
            style: `left:${x}%; top:${y}%;`,
        };
    }

    // Ensure fallback calculations mirror the radius used for the rendered dots
    getTargetRadiusPercent(value, type) {
        if (type === 'minute') {
            return 42;
        }
        if (this.hourMode === 24) {
            if (value === 0 || value > 12) {
                return 26;
            }
            return 43;
        }
        return 42;
    }

    isHourSelected(value) {
        if (this.hourMode === 24) return this.hour24 === value;
        const normalized = this.hour24 % 12 === 0 ? 12 : this.hour24 % 12;
        return normalized === value;
    }

    get is12HourMode() {
        return this.hourMode !== 24;
    }

    get amButtonClass() {
        const base = 'slds-button slds-button_neutral'; 
        return this.hour24 < 12 ? 'slds-button slds-button_brand' : base;
    }

    get pmButtonClass() {
        const base = 'slds-button slds-button_neutral';
        return this.hour24 >= 12 ? 'slds-button slds-button_brand' : base;
    }

    get handStyle() {
        const type = this.stage === 'hour' ? 'hour' : 'minute';
        let targetValue;

        if (this.isDragging && this.dragValue !== null) {
            targetValue = this.dragValue;
        } else {
            targetValue = this.stage === 'hour' ? this.displayHourNumber() : this.minute;
        }

        // 1. Get the raw target angle (0 - 360)
        const rawTargetAngle = this.calcAngle(targetValue, type);

        // 2. Calculate the difference from the current cumulative rotation
        let currentMod = this._totalRotation % 360;
        if (currentMod < 0) currentMod += 360;

        let diff = rawTargetAngle - currentMod;

        // 3. Normalize to shortest path (-180 to +180)
        if (diff < -180) diff += 360;
        if (diff > 180) diff -= 360;

        // 4. Apply the difference to the total accumulation
        this._totalRotation += diff;

        const faceEl = this.template.querySelector('.tcp-face');
        const faceRect = faceEl ? faceEl.getBoundingClientRect() : null;
        const faceWidth = faceRect ? faceRect.width : this.faceDiameter;
        const targetPercent = this.getTargetRadiusPercent(targetValue, type);

        let handHeightPx = null;
        const padding = 6;
        const fallbackHeight = () => {
            if (!faceWidth) return null;
            const dist = faceWidth * (targetPercent / 100);
            return Math.max(10, Math.round(dist - padding));
        };

        if (faceRect) {
            const faceCenterX = faceRect.left + faceRect.width / 2;
            const faceCenterY = faceRect.top + faceRect.height / 2;

            const selector = `.tcp-face button[data-value="${targetValue}"]`;
            const targetBtn = this.template.querySelector(selector);
            if (targetBtn) {
                const btn = targetBtn.getBoundingClientRect();
                const btnCenterX = btn.left + btn.width / 2;
                const btnCenterY = btn.top + btn.height / 2;
                const dist = Math.sqrt(Math.pow(btnCenterX - faceCenterX, 2) + Math.pow(btnCenterY - faceCenterY, 2));
                handHeightPx = Math.max(10, Math.round(dist - padding));
            } else {
                handHeightPx = fallbackHeight();
            }
        } else {
            handHeightPx = fallbackHeight();
        }

        const heightStyle = handHeightPx !== null ? `height:${handHeightPx}px;` : '';
        return `${heightStyle} transform: translateX(-50%) rotate(${this._totalRotation}deg);`;
    }

    displayHourNumber() {
        if (this.hourMode === 24) return this.hour24;
        const normalized = this.hour24 % 12;
        return normalized === 0 ? 12 : normalized;
    }

    calcAngle(value, type) {
        if (type === 'minute') return (360 / 60) * value;
        if (this.hourMode === 24) {
            let normalized;
            if (value === 0) normalized = 12;
            else normalized = value % 12 === 0 ? 12 : value % 12;
            return (360 / 12) * normalized;
        }
        const normalized = value % 12 === 0 ? 12 : value % 12;
        return (360 / 12) * normalized;
    }

    getAngleFromPosition(x, y) {
        const rect = this.template.querySelector('.tcp-face').getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        const centerY = rect.top + rect.height / 2;
        
        const deltaX = x - centerX;
        const deltaY = y - centerY;
        
        let angle = Math.atan2(deltaX, -deltaY) * (180 / Math.PI);
        if (angle < 0) angle += 360;
        
        return angle;
    }

    getDistanceFromCenter(x, y) {
        const rect = this.template.querySelector('.tcp-face').getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        const centerY = rect.top + rect.height / 2;
        
        const deltaX = x - centerX;
        const deltaY = y - centerY;
        
        return Math.sqrt(deltaX * deltaX + deltaY * deltaY);
    }

    getValueFromAngle(angle, type, distance = null) {
        if (type === 'hour') {
            // Double ring logic for 24h mode
            if (this.hourMode === 24 && distance !== null) {
                const faceRect = this.template.querySelector('.tcp-face').getBoundingClientRect();
                const faceRadius = faceRect.width / 2;
                const innerRadiusPx = faceRect.width * 0.26;
                const outerRadiusPx = faceRect.width * 0.43;
                const deltaInner = Math.abs(distance - innerRadiusPx);
                const deltaOuter = Math.abs(distance - outerRadiusPx);
                const isInnerRing = deltaInner <= deltaOuter;

                if (isInnerRing) {
                    const max = 12;
                    const step = 360 / max;
                    let value = Math.round(angle / step) % max;
                    if (value === 0) value = 12;
                    return value === 12 ? 0 : value + 12;
                } else {
                    const max = 12;
                    const step = 360 / max;
                    let value = Math.round(angle / step) % max;
                    return value === 0 ? 12 : value;
                }
            } else {
                const max = this.hourMode === 24 ? 24 : 12;
                const step = 360 / max;
                let value = Math.round(angle / step) % max;
                if (value === 0 && this.hourMode === 12) value = 12;
                return value;
            }
        } else {
            const step = 360 / 12;
            const position = Math.round(angle / step) % 12;
            return position * 5;
        }
    }

    handleFaceMouseDown = (event) => {
        if (this.disabled) return;
        this.isDragging = true;
        this.updateDragValue(event.clientX, event.clientY);
        document.addEventListener('mousemove', this.handleGlobalMouseMove);
        document.addEventListener('mouseup', this.handleGlobalMouseUp);
        event.preventDefault();
    };

    handleGlobalMouseMove = (event) => {
        if (this.isDragging) {
            this.updateDragValue(event.clientX, event.clientY);
        }
    };

    handleGlobalMouseUp = (event) => {
        if (this.isDragging) {
            this.isDragging = false;
            this.commitDragValue();
            document.removeEventListener('mousemove', this.handleGlobalMouseMove);
            document.removeEventListener('mouseup', this.handleGlobalMouseUp);
        }
    };

    updateDragValue(x, y) {
        const angle = this.getAngleFromPosition(x, y);
        const distance = this.getDistanceFromCenter(x, y);
        this.dragValue = this.getValueFromAngle(angle, this.stage, distance);
    }

    commitDragValue() {
        if (this.dragValue === null) return;
        if (this.stage === 'hour') {
            this.setHour(this.dragValue);
            this._value = this.formatTime(this.hour24, this.minute);
            this.stage = 'minute';
        } else {
            this.minute = this.dragValue;
        }
        this.dragValue = null;
    }

    togglePopover = () => {
        if (this.disabled) return;
        
        if (!this.showPopover) this.calculatePlacement();
        
        this.showPopover = !this.showPopover;
        
        if (this.showPopover) {
            this.stage = 'hour';
            this.syncFromValue(this._value);
        }
    };

    closePopover = () => {
        this.showPopover = false;
    };

    calculatePlacement() {
        const inputWrapper = this.template.querySelector('.slds-form-element__control');
        if (!inputWrapper) return; 
        const rect = inputWrapper.getBoundingClientRect();
        const popoverHeight = 450;
        const viewportHeight = window.innerHeight;
        const shouldFlip = (viewportHeight - rect.bottom) < popoverHeight;
        if (shouldFlip) {
            this.popoverClass = 'slds-popover slds-nubbin_bottom-right tcp-popover-custom tcp-flip-up';
        } else {
            this.popoverClass = 'slds-popover slds-nubbin_top-right tcp-popover-custom';
        }
    }

    handleFaceClick = (event) => {
        if (this.isDragging) return;        
        const val = Number(event.currentTarget.dataset.value);
        
        if (this.stage === 'hour') {
            this.setHour(val);
            this._value = this.formatTime(this.hour24, this.minute);
            this.stage = 'minute';
            return;
        }
        this.minute = val;
    };

    handleMeridianToggle(event) {
        event.stopPropagation();
        event.preventDefault();
        
        if (!this.is12HourMode) return;
        const shouldBePm = event.currentTarget.dataset.value === 'PM';
        
        if (this.isDragging && this.stage === 'hour' && this.dragValue !== null) {
            const normalized = this.dragValue === 12 ? 0 : this.dragValue;
            this.dragValue = shouldBePm ? normalized + 12 : normalized;
        } else {
            const normalized = this.hour24 % 12;
            this.hour24 = shouldBePm ? normalized + 12 : normalized;
        }
    }

    setHour(value) {
        if (this.hourMode === 24) {
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
        this.stage = 'minute';
        this.apply();
    };

    clearValue = () => {
        this.hour24 = 0;
        this.minute = 0;
        this._value = '';
        this.stage = 'hour';
        this.dispatchChange('');
        this.closePopover();
    };

    apply = () => {
        const hh = String(this.hour24).padStart(2, '0');
        const mm = String(this.minute).padStart(2, '0');
        const formatted = `${hh}:${mm}`;
        this._value = formatted;
        this.dispatchChange(formatted);
        this.closePopover();
    };

    dispatchChange(value) {
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value },
            bubbles: true,
            composed: true,
        }));
    }

    handleKeydown = (event) => {
        if (event.key === 'Escape') {
            this.closePopover();
            return;
        }
        
        if (event.key === 'Enter') {
            this.handleInputCommit();
            return;
        }

        if (this.showPopover) {
            event.preventDefault();
            
            if (this.stage === 'hour') {
                this.handleHourArrowKeys(event.key);
            } else {
                this.handleMinuteArrowKeys(event.key);
            }
        }
    };

    handleHourArrowKeys(key) {
        let currentHour = this.dragValue !== null ? this.dragValue : this.hour24;
        
        switch (key) {
            case 'ArrowUp':
                currentHour = (currentHour + 1) % (this.hourMode === 24 ? 24 : 12);
                if (this.hourMode === 12 && currentHour === 0) currentHour = 12;
                break;
            case 'ArrowDown':
                currentHour = currentHour - 1;
                if (currentHour < 0) {
                    currentHour = this.hourMode === 24 ? 23 : 12;
                }
                if (this.hourMode === 12 && currentHour === 0) currentHour = 12;
                break;
            case 'ArrowLeft':
                currentHour = (currentHour - 1 + (this.hourMode === 24 ? 24 : 12)) % (this.hourMode === 24 ? 24 : 12);
                if (this.hourMode === 12 && currentHour === 0) currentHour = 12;
                break;
            case 'ArrowRight':
                currentHour = (currentHour + 1) % (this.hourMode === 24 ? 24 : 12);
                if (this.hourMode === 12 && currentHour === 0) currentHour = 12;
                break;
        }
        
        this.dragValue = currentHour;
        this._value = this.formatTime(currentHour, this.minute);
    }

    handleMinuteArrowKeys(key) {
        let currentMinute = this.dragValue !== null ? this.dragValue : this.minute;
        
        switch (key) {
            case 'ArrowUp':
                currentMinute = (currentMinute + 5) % 60;
                break;
            case 'ArrowDown':
                currentMinute = currentMinute - 5;
                if (currentMinute < 0) currentMinute = 55;
                break;
            case 'ArrowLeft':
                currentMinute = (currentMinute - 5 + 60) % 60;
                break;
            case 'ArrowRight':
                currentMinute = (currentMinute + 5) % 60;
                break;
        }
        
        this.dragValue = currentMinute;
        this.minute = currentMinute;
    }

    handleInputChange = (event) => {
        const inputValue = event.target.value.replace(/\D/g, ''); // Only allow digits
        this.parseNumericInput(inputValue);
    };

    handleInputCommit() {
        if (this.validity.badInput) {
            this.reportValidity();
        } else {
            this.apply();
        }
    }

    parseNumericInput(input) {
        if (!input || input.trim() === '') {
            this.clearValue();
            return;
        }

        // Only accept numeric input and convert to HHMM format
        const digits = input.replace(/\D/g, '');
        
        if (digits.length === 0) {
            this.clearValue();
            return;
        }

        // Pad with zeros to ensure at least 4 digits for HHMM
        const padded = digits.padStart(4, '0');
        
        // Extract hours and minutes
        let hours = parseInt(padded.substring(0, 2), 10);
        let minutes = parseInt(padded.substring(2, 4), 10);

        // Validate ranges
        if (hours >= 0 && hours <= 23 && minutes >= 0 && minutes <= 59) {
            this.hour24 = hours;
            this.minute = minutes;
            this.validity.badInput = false;
            this.stage = 'minute'; // Move to minute stage for consistency
        } else {
            this.validity.badInput = true;
        }
    }

    syncFromValue(value) {
        this._value = value || '00:00';
        if (!value || value === '00:00') {
            this.hour24 = 0;
            this.minute = 0;
            return;
        }
        const parts = value.split(':');
        if (parts.length < 2) return;
        
        let hh = parseInt(parts[0], 10);
        let mm = parseInt(parts[1], 10);
        
        if (!isNaN(hh)) this.hour24 = Math.min(23, Math.max(0, hh));
        if (!isNaN(mm)) this.minute = Math.min(59, Math.max(0, mm));
    }

    formatTime(hours, minutes) {
        const hh = String(hours).padStart(2, '0');
        const mm = String(minutes).padStart(2, '0');
        return `${hh}:${mm}`;
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
            const input = this.template.querySelector('input');
            if (input) {
                input.setCustomValidity(this.getValidationMessage());
                input.reportValidity();
            }
        }
        return this.validity.valid;
    }

    updateValidity() {
        this.validity.valueMissing = this.required && !this._value;
        this.validity.badInput = false; // We'll handle this in input parsing
        this.validity.valid = !this.validity.valueMissing && !this.validity.badInput;
    }

    getValidationMessage() {
        if (this.validity.valueMissing) {
            return 'Complete this field.';
        }
        if (this.validity.badInput) {
            return 'Enter a valid time.';
        }
        return '';
    }
}