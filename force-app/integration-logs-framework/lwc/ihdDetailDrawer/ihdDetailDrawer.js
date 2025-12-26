import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class IhdDetailDrawer extends LightningElement {
    @api visible = false;
    @api record; 

    get log() {
        return this.record?.record || {};
    }

    get severity() {
        return this.record?.severity || 'INFO';
    }

    get isError() {
        const type = (this.log?.ObservationType__c || '').toUpperCase();
        return this.severity === 'ERROR' ||
               this.severity === 'FATAL' ||
               type.includes('EXCEPTION') ||
               type.includes('ERROR');
    }

    // --- Dynamic Classes ---

    get badgeClass() {
        const base = 'slds-badge slds-m-left_small';
        if (this.isError) return `${base} slds-theme_error`;
        if (this.severity === 'WARN') return `${base} slds-theme_warning`;
        if (this.severity === 'SUCCESS') return `${base} slds-theme_success`;
        return `${base} slds-theme_inverse`; 
    }

    get messageBoxClass() {
        return this.isError ? 'message-box-error' : 'message-box-info';
    }

    get messageIcon() {
        return this.isError ? 'utility:error' : 'utility:info';
    }

    get formattedContext() {
        const raw = this.log.Context__c || '';
        if (!raw) return 'No Payload';

        try {
            // First pass parsing
            let parsed = JSON.parse(raw);
            
            // Handle double-encoded JSON (common in logs)
            if (typeof parsed === 'string') {
                try {
                    parsed = JSON.parse(parsed);
                } catch (e2) {
                    // It was just a string, keep the first parse
                }
            }
            
            return JSON.stringify(parsed, null, 4);
        } catch (e) {
            // Not JSON? Just return the raw text
            return raw;
        }
    }

    // --- Actions ---

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleCopy() {
        const text = this.formattedContext;
        if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(text);
            this.showToast('Success', 'Payload copied to clipboard', 'success');
        } else {
            // Fallback for older browsers
            this.showToast('Error', 'Clipboard access denied', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}