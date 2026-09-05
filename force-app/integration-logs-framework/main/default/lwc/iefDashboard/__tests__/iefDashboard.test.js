const { createElement } = require("lwc");
import IefDashboard from "c/iefDashboard";

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
  "@salesforce/apex/IntegrationHealthController.canEditLogObservationType",
  () => ({
    default: jest.fn(() => Promise.resolve(false))
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
  "@salesforce/label/c.IEF_Tab_Summary",
  () => ({ default: "Summary" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IEF_Tab_Integrations",
  () => ({ default: "Integrations" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IEF_Tab_Filters",
  () => ({ default: "Filters" }),
  { virtual: true }
);
jest.mock("@salesforce/label/c.IEF_Tab_Admin", () => ({ default: "Admin" }), {
  virtual: true
});
jest.mock(
  "@salesforce/label/c.IEF_System_Pulse",
  () => ({ default: "System Pulse" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IEF_Loading",
  () => ({ default: "Loading..." }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IEF_Error_Loading_Summaries",
  () => ({ default: "Error loading summaries" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IEF_View_Grouped",
  () => ({ default: "Grouped" }),
  { virtual: true }
);
jest.mock(
  "@salesforce/label/c.IEF_View_Detailed",
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

describe("IefDashboard (smoke tests)", () => {
  let element;

  beforeEach(() => {
    element = createElement("c-ief-dashboard", {
      is: IefDashboard
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
    const hub = element.shadowRoot.querySelector("c-ief-event-hub");

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
    const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");
    const getIntegrationSummaries = require("@salesforce/apex/IntegrationHealthController.getIntegrationSummaries");

    // connectedCallback fires during document.body.appendChild
    await Promise.resolve();
    await Promise.resolve();

    expect(getIntegrationSummaries.default).toHaveBeenCalled();
    expect(getActiveCardPlugins.default).toHaveBeenCalled();
  });

  it("should refresh summary data when activity event fires from hub", async () => {
    const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");

    // Wait for initial load
    await Promise.resolve();
    await Promise.resolve();

    // Clear mock call counts from initial load
    getActiveCardPlugins.default.mockClear();

    // Simulate live activity from event hub
    const hub = element.shadowRoot.querySelector("c-ief-event-hub");
    hub.dispatchEvent(new CustomEvent("activity"));

    // Wait for the async refreshSummaryData calls
    await Promise.resolve();
    await Promise.resolve();

    expect(getActiveCardPlugins.default).toHaveBeenCalled();
  });

  it("should render summary child components after data loads", async () => {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();

    const statsCard = element.shadowRoot.querySelector("c-ief-stats-card");
    expect(statsCard).not.toBeNull();

    // No built-in breakdown/topErrors/trendIndicator components
    const breakdown = element.shadowRoot.querySelector(
      "c-ief-severity-breakdown"
    );
    expect(breakdown).toBeNull();

    const topErrors = element.shadowRoot.querySelector(
      "c-ief-top-error-integrations"
    );
    expect(topErrors).toBeNull();

    const trendIndicator = element.shadowRoot.querySelector(
      "c-ief-trend-indicator"
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
    element = createElement("c-ief-dashboard", {
      is: IefDashboard
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

    element = createElement("c-ief-dashboard", {
      is: IefDashboard
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

    element = createElement("c-ief-dashboard", {
      is: IefDashboard
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

    element = createElement("c-ief-dashboard", {
      is: IefDashboard
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

  it("placeholder renders label for provider-less card", async () => {
    document.body.removeChild(element);
    const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");
    getActiveCardPlugins.default.mockResolvedValue([
      {
        developerName: "Missing_Card",
        label: "Missing Card Label",
        name: "Missing Card",
        componentName: "c-missing-card-xyz",
        order: 1,
        cardLocation: "summary",
        description: "Test missing",
        gridSpan: 1
      }
    ]);
    element = createElement("c-ief-dashboard", {
      is: IefDashboard
    });
    document.body.appendChild(element);
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    // Verify the plugin is present with correct label and no constructor (placeholder path)
    expect(element.summaryPlugins.length).toBe(1);
    expect(element.summaryPlugins[0].label).toBe("Missing Card Label");
    expect(element.summaryPlugins[0].hasCtor).toBe(false);
    // Verify placeholder is rendered with the label
    const placeholder = element.shadowRoot.querySelector(
      "c-ief-card-placeholder"
    );
    expect(placeholder).not.toBeNull();
    // LWC jest stubs expose api props as attributes/properties
    // Check that the placeholder received the label
    expect(
      placeholder.pluginLabel || placeholder.getAttribute("plugin-label")
    ).toBeTruthy();
  });

  it("healthy card renders data without placeholder when provider available", async () => {
    document.body.removeChild(element);
    const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");
    // Use a real LWC constructor as dummy to satisfy lwc:is validation
    const { registerCard, clearRegistry } = require("c/iefDynamicLoader");
    try {
      clearRegistry();
    } catch {
      // ignore
    }
    // Import an existing valid LWC component to use as dummy ctor
    // c/iefCardPlaceholder is a valid LWC with registered name
    const DummyCard = require("c/iefCardPlaceholder").default;
    registerCard("c-healthy-card-xyz", DummyCard);

    getActiveCardPlugins.default.mockResolvedValue([
      {
        developerName: "Healthy_Card",
        label: "Healthy Card",
        name: "Healthy Card",
        componentName: "c-healthy-card-xyz",
        order: 1,
        cardLocation: "summary",
        description: "Healthy",
        gridSpan: 1
      }
    ]);
    element = createElement("c-ief-dashboard", {
      is: IefDashboard
    });
    document.body.appendChild(element);
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    expect(element.summaryPlugins.length).toBe(1);
    expect(element.summaryPlugins[0].label).toBe("Healthy Card");
    expect(element.summaryPlugins[0].hasCtor).toBe(true);
    // When healthy, placeholder should not be rendered
    const placeholder = element.shadowRoot.querySelector(
      "c-ief-card-placeholder"
    );
    expect(placeholder).toBeNull();
    try {
      clearRegistry();
    } catch {
      // ignore
    }
  });

  it("skipped plugin renders placeholder with reason while other cards render", async () => {
    document.body.removeChild(element);
    const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");
    const { registerCard, clearRegistry } = require("c/iefDynamicLoader");
    try {
      clearRegistry();
    } catch {
      // ignore
    }
    const DummyCard = require("c/iefCardPlaceholder").default;
    registerCard("c-healthy-card-xyz", DummyCard);

    getActiveCardPlugins.default.mockResolvedValue([
      {
        developerName: "Healthy_Card",
        label: "Healthy Card",
        name: "Healthy Card",
        componentName: "c-healthy-card-xyz",
        order: 1,
        cardLocation: "summary",
        description: "Healthy",
        gridSpan: 1
      },
      {
        developerName: "Future_Card",
        label: "Future Card Label",
        name: "Future Card",
        componentName: "c-future-card-xyz",
        order: 2,
        cardLocation: "summary",
        description: "Future plugin requiring 2.0",
        gridSpan: 1,
        reason:
          "Contract version mismatch: plugin Future_Card requires 2.0 but host supports 1.x"
      }
    ]);
    element = createElement("c-ief-dashboard", {
      is: IefDashboard
    });
    document.body.appendChild(element);
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
    expect(element.summaryPlugins.length).toBe(2);
    // Healthy card has ctor
    const healthy = element.summaryPlugins.find(
      (p) => p.developerName === "Healthy_Card"
    );
    expect(healthy.hasCtor).toBe(true);
    // Future card has no ctor and carries reason
    const skipped = element.summaryPlugins.find(
      (p) => p.developerName === "Future_Card"
    );
    expect(skipped.hasCtor).toBe(false);
    expect(skipped.reason).toContain("Contract version mismatch");
    // Dashboard renders one live card plus one placeholder
    const placeholders = element.shadowRoot.querySelectorAll(
      "c-ief-card-placeholder"
    );
    expect(placeholders.length).toBe(1);
    expect(
      placeholders[0].pluginReason ||
        placeholders[0].getAttribute("plugin-reason")
    ).toContain("Contract version mismatch");
    try {
      clearRegistry();
    } catch {
      // ignore
    }
  });

  describe("LMS Plugin Actions & Registration", () => {
    it("handles valid navigate_to_filters action with observationType (C4 resolution)", async () => {
      element = createElement("c-ief-dashboard", {
        is: IefDashboard
      });
      document.body.appendChild(element);
      await Promise.resolve();

      const message = {
        action: "navigate_to_filters",
        pluginName: "iefSeverityCardImpl",
        payload: {
          fromDate: "2026-08-01T00:00:00Z",
          toDate: "2026-08-24T23:59:59Z",
          integrationCode: "PAYMENT_GATEWAY",
          searchTerm: "TIMEOUT",
          observationType: "Error"
        }
      };

      element.handlePluginAction(message);
      await Promise.resolve();

      const tabset = element.shadowRoot.querySelector("lightning-tabset");
      expect(tabset.activeTabValue).toBe("filters");

      const filters = element.shadowRoot.querySelector("c-ief-filters");
      expect(filters.observationValue).toBe("Error");
      expect(filters.integrationCodeValue).toBe("PAYMENT_GATEWAY");
      expect(filters.searchValue).toBe("TIMEOUT");
      expect(filters.fromValue).toBe("2026-08-01T00:00:00Z");
      expect(filters.toValue).toBe("2026-08-24T23:59:59Z");
    });

    it("handles refresh_dashboard action", async () => {
      const getIntegrationSummaries = require("@salesforce/apex/IntegrationHealthController.getIntegrationSummaries");
      element = createElement("c-ief-dashboard", {
        is: IefDashboard
      });
      document.body.appendChild(element);
      await Promise.resolve();

      getIntegrationSummaries.default.mockClear();
      element.handlePluginAction({
        action: "refresh_dashboard",
        pluginName: "testPlugin"
      });
      await Promise.resolve();

      expect(getIntegrationSummaries.default).toHaveBeenCalled();
    });

    it("safely ignores invalid or unsupported action messages", async () => {
      element = createElement("c-ief-dashboard", {
        is: IefDashboard
      });
      document.body.appendChild(element);
      await Promise.resolve();

      const tabset = element.shadowRoot.querySelector("lightning-tabset");
      const initialTab = tabset.activeTabValue;
      element.handlePluginAction(null);
      element.handlePluginAction({});
      element.handlePluginAction({ action: "unsupported_action" });
      await Promise.resolve();

      expect(tabset.activeTabValue).toBe(initialTab);
    });

    it("handles card registration message and triggers fetchActivePlugins", async () => {
      const getActiveCardPlugins = require("@salesforce/apex/IntegrationHealthController.getActiveCardPlugins");
      element = createElement("c-ief-dashboard", {
        is: IefDashboard
      });
      document.body.appendChild(element);
      await Promise.resolve();

      getActiveCardPlugins.default.mockClear();
      element.handleCardRegistration({
        action: "register",
        cardName: "c-test-card"
      });
      await Promise.resolve();

      expect(getActiveCardPlugins.default).toHaveBeenCalled();
    });
  });
});
