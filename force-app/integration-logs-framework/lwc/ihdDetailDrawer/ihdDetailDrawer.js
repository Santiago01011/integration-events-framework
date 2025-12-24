import { LightningElement, api } from 'lwc';

export default class IhdDetailDrawer extends LightningElement {
    @api visible = false;
    @api record; // This is now the wrapper { record: ..., severity: ... }

    get log() {
        return this.record?.record || {};
    }

    get severity() {
        return this.record?.severity || 'INFO';
    }

    get badgeClass() {
        const baseClass = 'slds-badge slds-var-m-left_small';
        switch (this.severity) {
            case 'ERROR':
            case 'FATAL':
                return `${baseClass} slds-theme_error`;
            case 'WARN':
                return `${baseClass} slds-theme_warning`;
            case 'INFO':
                return `${baseClass} slds-theme_info`;
            default:
                return `${baseClass} slds-theme_alt-inverse`;
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}