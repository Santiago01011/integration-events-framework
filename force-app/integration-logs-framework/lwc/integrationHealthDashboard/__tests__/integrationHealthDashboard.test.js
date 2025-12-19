const { createElement } = require('lwc');
import IntegrationHealthDashboard from 'c/integrationHealthDashboard';

// Mock Salesforce modules
jest.mock('@salesforce/apex/IntegrationHealthController.getRecentLogs', () => ({
    default: jest.fn()
}), { virtual: true });

jest.mock('@salesforce/apex/IntegrationHealthController.getAggregates', () => ({
    default: jest.fn()
}), { virtual: true });

jest.mock('@salesforce/apex/IntegrationHealthController.setLogProcessed', () => ({
    default: jest.fn()
}), { virtual: true });

// empApi subscribe returns a Promise that resolves to a subscription object in real usage
jest.mock('lightning/empApi', () => ({
    subscribe: jest.fn(() => Promise.resolve({ channel: '/event/IntegrationEvent__e' })),
    unsubscribe: jest.fn(() => Promise.resolve()),
    onError: jest.fn(),
    isEmpEnabled: jest.fn(() => true)
}), { virtual: true });

// ShowToastEvent should be a real CustomEvent in tests so dispatchEvent works
jest.mock('lightning/platformShowToastEvent', () => ({
    ShowToastEvent: function (config) {
        return new CustomEvent('toast', { detail: config });
    }
}), { virtual: true });

describe('IntegrationHealthDashboard (smoke tests)', () => {
    let element;

    beforeEach(() => {
        element = createElement('c-integration-health-dashboard', {
            is: IntegrationHealthDashboard
        });
        document.body.appendChild(element);
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('should render the component', () => {
        expect(element).toBeTruthy();
    });

    it('should display the overview card title', () => {
        return Promise.resolve().then(() => {
            const card = element.shadowRoot.querySelector('lightning-card');
            // the overview card title is rendered by the component
            expect(card).toBeTruthy();
            expect(card.title).toBe('Integration Health Overview');
        });
    });

    it('should attempt to subscribe to EMP API when connected', () => {
        // import the mocked module to assert calls
        const empApi = require('lightning/empApi');
        return Promise.resolve().then(() => {
            expect(empApi.subscribe).toHaveBeenCalled();
        });
    });
});
