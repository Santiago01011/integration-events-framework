import { createElement } from "lwc";
import IefRegistryHealthCard from "c/iefRegistryHealthCard";
import getCardData from "@salesforce/apex/IEF_RegistryHealthCardPlugin.getCardData";

jest.mock(
  "@salesforce/apex/IEF_RegistryHealthCardPlugin.getCardData",
  () => ({
    default: jest.fn()
  }),
  { virtual: true }
);

describe("c-ief-registry-health-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  function flushPromises() {
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    return new Promise((resolve) => setTimeout(resolve, 0));
  }

  it("renders mocked composition entries (active + failed)", async () => {
    const mockEntries = [
      {
        developerName: "Severity_Card",
        label: "Severity Card",
        pluginType: "CARD",
        apexClassName: "IEF_SeverityCardPlugin",
        lwcComponentName: "iefSeverityCardImpl",
        displayOrder: 1,
        status: "ACTIVE",
        reason: null,
        contractVersion: "1.0",
        enabled: true
      },
      {
        developerName: "Broken_Card",
        label: "Broken Card",
        pluginType: "CARD",
        apexClassName: "NonExistent_Class",
        lwcComponentName: "brokenImpl",
        displayOrder: 2,
        status: "FAILED",
        reason: "Failed to instantiate NonExistent_Class: Type not found",
        contractVersion: "1.0",
        enabled: true
      },
      {
        developerName: "Future_Card",
        label: "Future Card",
        pluginType: "CARD",
        apexClassName: "IEF_FutureCardPlugin",
        lwcComponentName: "futureImpl",
        displayOrder: 3,
        status: "SKIPPED_VERSION_MISMATCH",
        reason:
          "Contract version mismatch: plugin Future_Card requires 2.0 but host supports 1.x",
        contractVersion: "2.0",
        enabled: true
      }
    ];
    getCardData.mockResolvedValue(mockEntries);

    const element = createElement("c-ief-registry-health-card", {
      is: IefRegistryHealthCard
    });
    element.contextData = JSON.stringify({
      pluginName: "Registry_Health",
      filters: {},
      location: "dashboard",
      refreshToken: "123",
      capabilities: { canExport: true, canFilter: true, canRefresh: true }
    });
    document.body.appendChild(element);

    await flushPromises();
    await Promise.resolve();
    await Promise.resolve();

    // Should have rendered rows
    const rows = element.shadowRoot.querySelectorAll("tbody tr");
    expect(rows.length).toBe(3);

    const text = element.shadowRoot.textContent;
    expect(text).toContain("Severity Card");
    expect(text).toContain("ACTIVE");
    expect(text).toContain("Broken Card");
    expect(text).toContain("FAILED");
    expect(text).toContain("Failed to instantiate");
    expect(text).toContain("Future Card");
    expect(text).toContain("SKIPPED_VERSION_MISMATCH");
    expect(text).toContain("Contract version mismatch");
  });

  it("shows empty state when no plugins", async () => {
    getCardData.mockResolvedValue([]);
    const element = createElement("c-ief-registry-health-card", {
      is: IefRegistryHealthCard
    });
    document.body.appendChild(element);
    await flushPromises();
    await Promise.resolve();

    const text = element.shadowRoot.textContent;
    expect(text).toContain("No plugins registered");
  });

  it("shows error when Apex throws", async () => {
    getCardData.mockRejectedValue({ body: { message: "Apex error" } });
    const element = createElement("c-ief-registry-health-card", {
      is: IefRegistryHealthCard
    });
    document.body.appendChild(element);
    await flushPromises();
    await Promise.resolve();

    const text = element.shadowRoot.textContent;
    expect(text).toContain("Apex error");
  });

  it("hasValidContext returns true after parse", async () => {
    getCardData.mockResolvedValue([]);
    const element = createElement("c-ief-registry-health-card", {
      is: IefRegistryHealthCard
    });
    element.contextData = JSON.stringify({ filters: {} });
    document.body.appendChild(element);
    await flushPromises();
    expect(element.hasValidContext).toBe(true);
  });
});
