import { LightningElement, api, track } from 'lwc';

const MINUTE_INTERVALS = 12;

export default class TimeClockPicker extends LightningElement {
    @api label = '';
    @api required = false;
    @api disabled = false;
    @api hourMode = 12;

    _value = '';
    
    @track showPopover = false;
    @track stage = 'hour';
    @track hour24 = 0;
    @track minute = 0;

    @api
    get value() {
        return this._value;
    }

    set value(val) {
        this.syncFromValue(val);
    }

    connectedCallback() {
        this.syncFromValue(this._value);
    }

    get displayValue() {
        if (!this._value) return '';
        return this.formatTime(this.hour24, this.minute);
    }

    get stageLabel() {
        return this.stage === 'hour' ? 'Select Hour' : 'Select Minute';
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
        // Slightly adjusted radius for the new 280px face
        const maxRadius = type === 'hour' && this.hourMode === 24 ? 38 : 42; 
        const angle = this.calcAngle(value, type);
        const x = 50 + maxRadius * Math.sin((Math.PI / 180) * angle);
        const y = 50 - maxRadius * Math.cos((Math.PI / 180) * angle);
        
        return {
            value,
            label: type === 'hour' && this.hourMode === 24 ? String(value).padStart(2, '0') : value,
            className: selected ? 'tcp-dot tcp-selected' : 'tcp-dot',
            style: `left:${x}%; top:${y}%;`,
        };
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
        const targetValue = this.stage === 'hour' ? this.displayHourNumber() : this.minute;
        return `transform: rotate(${this.calcAngle(targetValue, type)}deg);`;
    }

    displayHourNumber() {
        if (this.hourMode === 24) return this.hour24;
        const normalized = this.hour24 % 12;
        return normalized === 0 ? 12 : normalized;
    }

    calcAngle(value, type) {
        if (type === 'minute') return (360 / 60) * value;
        const max = this.hourMode === 24 ? 24 : 12;
        const normalized = this.hourMode === 24 ? value : (value % 12 === 0 ? 12 : value % 12);
        return (360 / max) * normalized;
    }

    togglePopover = () => {
        if (this.disabled) return;
        this.showPopover = !this.showPopover;
        if (this.showPopover) {
            this.stage = 'hour';
            this.syncFromValue(this._value);
        }
    };

    closePopover = () => {
        this.showPopover = false;
    };

    handleFaceClick = (event) => {
        const val = Number(event.currentTarget.dataset.value);
        
        if (this.stage === 'hour') {
            this.setHour(val);
            // Wait for animation before switching
            setTimeout(() => {
                this.stage = 'minute';
            }, 450); 
            return;
        }
        this.minute = val;
        this.apply();
    };

    handleMeridianToggle(event) {
        if (!this.is12HourMode) return;
        const shouldBePm = event.currentTarget.dataset.value === 'PM';
        const normalized = this.hour24 % 12;
        this.hour24 = shouldBePm ? normalized + 12 : normalized;
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
        if (event.key === 'Escape') this.closePopover();
    };

    syncFromValue(value) {
        this._value = value || '';
        if (!value) {
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
}