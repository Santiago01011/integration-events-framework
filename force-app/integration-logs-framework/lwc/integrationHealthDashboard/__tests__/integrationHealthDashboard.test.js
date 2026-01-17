const { createElement } = require("lwc");
import IntegrationHealthDashboard from "c/integrationHealthDashboard";

// Mock Salesforce modules
jest.mock(
  "@salesforce/apex/IntegrationHealthController.getRecentLogs",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getLogDetail",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getIntegrationSummaries",
  () => ({
    default: jest.fn(() => Promise.resolve([]))
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getEventChannel",
  () => ({
    default: jest.fn(() => Promise.resolve("/event/IntegrationEvent__e"))
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.isAdminUser",
  () => ({
    default: jest.fn(() => Promise.resolve(false))
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getAggregates",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.setLogProcessed",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

// Mock c/utilsLogsApi
jest.mock(
  "c/utilsLogsApi",
  () => ({
    default: {
      fetchPage: jest.fn(() =>
        Promise.resolve({ records: [], hasMore: false })
      ),
      clearCache: jest.fn(),
      invalidateForRecord: jest.fn(),
      getCacheSnapshot: jest.fn(() => ({})),
      debounce: jest.fn((fn) => fn),
      initRealtime: jest.fn(() => Promise.resolve()),
      unsubscribeFromLogs: jest.fn()
    },
    fetchPage: jest.fn(() => Promise.resolve({ records: [], hasMore: false })),
    clearCache: jest.fn(),
    invalidateForRecord: jest.fn(),
    getCacheSnapshot: jest.fn(() => ({})),
    debounce: jest.fn((fn) => fn),
    initRealtime: jest.fn(() => Promise.resolve()),
    unsubscribeFromLogs: jest.fn()
  }),
  { virtual: true }
);

// empApi subscribe returns a Promise that resolves to a subscription object in real usage
jest.mock(
  "lightning/empApi",
  () => ({
    subscribe: jest.fn(() =>
      Promise.resolve({ channel: "/event/IntegrationEvent__e" })
    ),
    unsubscribe: jest.fn(() => Promise.resolve()),
    onError: jest.fn(),
    isEmpEnabled: jest.fn(() => true)
  }),
  { virtual: true }
);

// ShowToastEvent should be a real CustomEvent in tests so dispatchEvent works
jest.mock(
  "lightning/platformShowToastEvent",
  () => ({
    ShowToastEvent: function (config) {
      return new CustomEvent("toast", { detail: config });
    }
  }),
  { virtual: true }
);

describe("IntegrationHealthDashboard (smoke tests)", () => {
  let element;

  beforeEach(() => {
    element = createElement("c-integration-health-dashboard", {
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

  it("should render the component", () => {
    expect(element).toBeTruthy();
  });

  it("should display the tabset with tabs", () => {
    return Promise.resolve().then(() => {
      const tabset = element.shadowRoot.querySelector("lightning-tabset");
      expect(tabset).toBeTruthy();
      const tabs = element.shadowRoot.querySelectorAll("lightning-tab");
      expect(tabs.length).toBeGreaterThan(0);
    });
  });
});
