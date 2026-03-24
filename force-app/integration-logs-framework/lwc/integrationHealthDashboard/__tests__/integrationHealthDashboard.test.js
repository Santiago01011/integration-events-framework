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
  "@salesforce/apex/IntegrationHealthController.canManagePlugins",
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

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getSeverityCounts",
  () => ({
    default: jest.fn(() =>
      Promise.resolve([
        { severity: "SUCCESS", count: 100, percentage: 72 },
        { severity: "ERROR", count: 28, percentage: 20 },
        { severity: "WARN", count: 12, percentage: 8 }
      ])
    )
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getTopErrorIntegrations",
  () => ({
    default: jest.fn(() =>
      Promise.resolve([
        {
          integrationCode: "SAP",
          displayName: "SAP Integration",
          errorCount: 50,
          totalEvents: 200,
          trend: "up"
        }
      ])
    )
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getHourlyTrend",
  () => ({
    default: jest.fn(() =>
      Promise.resolve({
        points: [
          { hour: "10:00", total: 10 },
          { hour: "11:00", total: 5 }
        ],
        direction: "up",
        delta: 3.2
      })
    )
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.deleteLog",
  () => ({
    default: jest.fn(() => Promise.resolve())
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.updateLogObservation",
  () => ({
    default: jest.fn(() => Promise.resolve())
  }),
  { virtual: true }
);

// Mock custom labels
jest.mock(
  "@salesforce/label/c.IHD_Tab_Summary",
  () => ({ default: "Summary" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IHD_Tab_Integrations",
  () => ({ default: "Integrations" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IHD_Tab_Filters",
  () => ({ default: "Filters" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.IHD_Tab_Admin", () => ({ default: "Admin" }), {
  virtual: true
});
jest.mock(
  "@salesforce/label/c.IHD_System_Pulse",
  () => ({ default: "System Pulse" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IHD_Loading",
  () => ({ default: "Loading..." }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IHD_Error_Loading_Summaries",
  () => ({ default: "Error loading summaries" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IHD_View_Grouped",
  () => ({ default: "Grouped" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IHD_View_Detailed",
  () => ({ default: "Detailed" }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getActiveCardPlugins",
  () => ({
    default: jest.fn(() => Promise.resolve([]))
  }),
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getCardPluginData",
  () => ({
    default: jest.fn(() => Promise.resolve({}))
  }),
  { virtual: true }
);

// Mock LightningConfirm and LightningPrompt
jest.mock(
  "lightning/confirm",
  () => ({
    default: { open: jest.fn(() => Promise.resolve(true)) }
  }),
  { virtual: true }
);
jest.mock(
  "lightning/prompt",
  () => ({
    default: { open: jest.fn(() => Promise.resolve("NEW_TYPE")) }
  }),
  { virtual: true }
);

// Mock c/utilsLogsApi
jest.mock(
  "c/utilsLogsApi",
  () => {
    const mock = {
      fetchPage: jest.fn(() =>
        Promise.resolve({ records: [], hasMore: false })
      ),
      clearCache: jest.fn(),
      invalidateForRecord: jest.fn(),
      getCacheSnapshot: jest.fn(() => ({})),
      debounce: jest.fn((fn) => fn),
      initRealtime: jest.fn(() => Promise.resolve()),
      unsubscribeFromLogs: jest.fn(),
      calculateGlobalStats: jest.fn(() => ({
        total: 0,
        errors: 0,
        success: 0,
        successRate: 0,
        errorRate: 0,
        progressStyle: ""
      })),
      transformRow: jest.fn((row) => row),
      transformEventToRow: jest.fn((ev) => ev),
      buildLocalDetailWrapper: jest.fn((row) => ({ record: row })),
      showToast: jest.fn(),
      BASE_COLUMNS: []
    };
    return {
      default: mock,
      ...mock
    };
  },
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

  it("should render header badge on load", () => {
    return Promise.resolve().then(() => {
      return Promise.resolve().then(() => {
        const badge = element.shadowRoot.querySelector(".live-status-badge");
        expect(badge).toBeTruthy();
        // Badge should render with a status text (Live, Stale, or Offline)
        expect(badge.textContent.length).toBeGreaterThan(0);
      });
    });
  });

  it("should update status badge when hub notifies", () => {
    const hub = element.shadowRoot.querySelector("c-ihd-event-hub");

    // Simulate connected
    hub.dispatchEvent(
      new CustomEvent("statuschange", {
        detail: { isConnected: true, isStale: false }
      })
    );

    return Promise.resolve().then(() => {
      const badge = element.shadowRoot.querySelector(".live-status-badge");
      expect(badge).toBeTruthy();
      expect(badge.classList.contains("live-status-badge--connected")).toBe(
        true
      );
      expect(badge.textContent).toContain("Live");

      // Simulate stale
      hub.dispatchEvent(
        new CustomEvent("statuschange", {
          detail: { isConnected: true, isStale: true }
        })
      );

      return Promise.resolve().then(() => {
        expect(badge.classList.contains("live-status-badge--stale")).toBe(true);
        expect(badge.textContent).toContain("Stale");

        // Simulate disconnected
        hub.dispatchEvent(
          new CustomEvent("statuschange", {
            detail: { isConnected: false, isStale: false }
          })
        );

        return Promise.resolve().then(() => {
          expect(
            badge.classList.contains("live-status-badge--disconnected")
          ).toBe(true);
          expect(badge.textContent).toContain("Offline");
        });
      });
    });
  });

  // --- Summary tab integration tests (Phase 8.5) ---

  it("should call summary data fetchers on connectedCallback", async () => {
    const getSeverityCounts = require("@salesforce/apex/IntegrationHealthController.getSeverityCounts");
    const getTopErrorIntegrations = require("@salesforce/apex/IntegrationHealthController.getTopErrorIntegrations");

    // connectedCallback fires during document.body.appendChild
    await Promise.resolve();
    await Promise.resolve();

    expect(getSeverityCounts.default).toHaveBeenCalled();
    expect(getTopErrorIntegrations.default).toHaveBeenCalled();
  });

  it("should refresh summary data when activity event fires from hub", async () => {
    const getSeverityCounts = require("@salesforce/apex/IntegrationHealthController.getSeverityCounts");
    const getTopErrorIntegrations = require("@salesforce/apex/IntegrationHealthController.getTopErrorIntegrations");

    // Wait for initial load
    await Promise.resolve();
    await Promise.resolve();

    // Clear mock call counts from initial load
    getSeverityCounts.default.mockClear();
    getTopErrorIntegrations.default.mockClear();

    // Simulate live activity from event hub
    const hub = element.shadowRoot.querySelector("c-ihd-event-hub");
    hub.dispatchEvent(new CustomEvent("activity"));

    // Wait for the async refreshSummaryData calls
    await Promise.resolve();
    await Promise.resolve();

    expect(getSeverityCounts.default).toHaveBeenCalled();
    expect(getTopErrorIntegrations.default).toHaveBeenCalled();
  });

  it("should render summary child components after data loads", async () => {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    const statsCard = element.shadowRoot.querySelector("c-ihd-stats-card");
    expect(statsCard).not.toBeNull();

    // No built-in breakdown/topErrors/trendIndicator components
    const breakdown = element.shadowRoot.querySelector(
      "c-ihd-severity-breakdown"
    );
    expect(breakdown).toBeNull();

    const topErrors = element.shadowRoot.querySelector(
      "c-ihd-top-error-integrations"
    );
    expect(topErrors).toBeNull();

    const trendIndicator = element.shadowRoot.querySelector(
      "c-ihd-trend-indicator"
    );
    expect(trendIndicator).toBeNull();
  });

  // --- Phase 4: Dynamic UI Extensibility ---

  it("should filter summaryPlugins excluding integrations-only plugins", async () => {
    // Clean up the default element first
    document.body.removeChild(element);

    const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");
    getActiveCardPlugins.default.mockResolvedValue([
      {
        name: "SummaryCard",
        componentName: "c-summary",
        cardLocation: "summary",
        order: 1
      },
      {
        name: "IntegrationCard",
        componentName: "c-integration",
        cardLocation: "integrations",
        order: 2
      },
      {
        name: "BothCard",
        componentName: "c-both",
        cardLocation: "both",
        order: 3
      },
      { name: "DefaultCard", componentName: "c-default", order: 4 }
    ]);

    // Create element AFTER mock is set so connectedCallback uses the correct data
    element = createElement("c-integration-health-dashboard", {
      is: IntegrationHealthDashboard
    });
    document.body.appendChild(element);

    // Wait for async data fetch
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    // summaryPlugins should include: summary, both, and undefined (default)
    expect(element.summaryPlugins.length).toBe(3);
    expect(element.summaryPlugins.map((p) => p.name)).toEqual([
      "SummaryCard",
      "BothCard",
      "DefaultCard"
    ]);
  });

  it("should filter integrationPlugins excluding summary-only plugins", async () => {
    document.body.removeChild(element);

    const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");
    getActiveCardPlugins.default.mockResolvedValue([
      {
        name: "SummaryCard",
        componentName: "c-summary",
        cardLocation: "summary",
        order: 1
      },
      {
        name: "IntegrationCard",
        componentName: "c-integration",
        cardLocation: "integrations",
        order: 2
      },
      {
        name: "BothCard",
        componentName: "c-both",
        cardLocation: "both",
        order: 3
      },
      { name: "DefaultCard", componentName: "c-default", order: 4 }
    ]);

    element = createElement("c-integration-health-dashboard", {
      is: IntegrationHealthDashboard
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    // integrationPlugins should include: integrations, both, and undefined (default)
    expect(element.integrationPlugins.length).toBe(3);
    expect(element.integrationPlugins.map((p) => p.name)).toEqual([
      "IntegrationCard",
      "BothCard",
      "DefaultCard"
    ]);
  });

  it("should return empty summaryPlugins when activePlugins is empty", async () => {
    document.body.removeChild(element);

    const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");
    getActiveCardPlugins.default.mockResolvedValue([]);

    element = createElement("c-integration-health-dashboard", {
      is: IntegrationHealthDashboard
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    expect(element.summaryPlugins).toEqual([]);
    expect(element.integrationPlugins).toEqual([]);
  });

  it("should render plugin hosts in the integrations tab for integrationPlugins", async () => {
    document.body.removeChild(element);

    const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");
    getActiveCardPlugins.default.mockResolvedValue([
      {
        name: "IntegrationCard",
        componentName: "c-unknown-plugin",
        cardLocation: "integrations",
        description: "Integration plugin"
      }
    ]);

    element = createElement("c-integration-health-dashboard", {
      is: IntegrationHealthDashboard
    });
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    // Summary tab should not have this plugin
    expect(element.summaryPlugins.length).toBe(0);
    // Integrations tab should have it
    expect(element.integrationPlugins.length).toBe(1);
  });
});
