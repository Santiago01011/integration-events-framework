import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class IhdDetailDrawer extends LightningElement {
    @api visible = false;
    @api record;

    get formattedStackTrace() {
        if (this.record && this.record.StackTrace__c) {
            try {
                const parsed = JSON.parse(this.record.StackTrace__c);
                return JSON.stringify(parsed, null, 4);
            } catch {
                return this.record.StackTrace__c;
            }
        }
        return '';
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleMarkProcessed(event) {
        const recordId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('markprocessed', {
            detail: recordId
        }));
    }

    handleReopen(event) {
        const recordId = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('reopen', {
            detail: recordId
        }));
    }

    async handleCopyPayloadId() {
        if (this.record?.PayloadId__c) {
            await this.copyToClipboard(this.record.PayloadId__c);
            this.showToast('Copied', 'Payload ID copied to clipboard', 'success');
        }
    }

    async handleCopyJobId() {
        if (this.record?.JobId__c) {
            await this.copyToClipboard(this.record.JobId__c);
            this.showToast('Copied', 'Job ID copied to clipboard', 'success');
        }
    }

    async handleCopyMessage() {
        if (this.record?.Message__c) {
            await this.copyToClipboard(this.record.Message__c);
            this.showToast('Copied', 'Message copied to clipboard', 'success');
        }
    }

    async handleCopyStackTrace() {
        if (this.record?.StackTrace__c) {
            await this.copyToClipboard(this.record.StackTrace__c);
            this.showToast('Copied', 'Stack trace copied to clipboard', 'success');
        }
    }

    async copyToClipboard(text) {
        try {
            await navigator.clipboard.writeText(text);
        } catch {
            // Fallback for older browsers
            const textArea = document.createElement('textarea');
            textArea.value = text;
            document.body.appendChild(textArea);
            textArea.select();
            document.execCommand('copy');
            document.body.removeChild(textArea);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}