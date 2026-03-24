import { createElement } from "lwc";
import IhdPluginHost from "c/ihdPluginHost";

jest.mock(
  "@salesforce/apex/IntegrationHealthController.getCardPluginData",
  () => ({
    default: jest.fn(() => Promise.resolve({ totalEvents: 42 }))
  }),
  { virtual: true }
);

describe("c-ihd-plugin-host", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders nothing when no plugin is provided", () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = null;
    document.body.appendChild(element);

    expect(element.shadowRoot.querySelector(".slds-card")).toBeNull();
  });

  it("renders the fallback card for plugin content", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "CustomPlugin",
      componentName: "c-custom-plugin",
      description: "A custom third-party plugin"
    };
    document.body.appendChild(element);
    await Promise.resolve();

    expect(element.shadowRoot.querySelector(".fallback-card")).not.toBeNull();
    expect(
      element.shadowRoot.querySelector(".slds-card__header-title").textContent
    ).toContain("CustomPlugin");
    expect(element.shadowRoot.querySelector("code").textContent).toBe(
      "c-custom-plugin"
    );
  });

  it("renders object data as key-value pairs in fallback mode", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "DataPlugin",
      componentName: "c-data-plugin",
      data: { totalEvents: 42, status: "healthy" }
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const keys = element.shadowRoot.querySelectorAll(".fallback-data-key");
    const values = element.shadowRoot.querySelectorAll(".fallback-data-value");

    expect(keys.length).toBe(2);
    expect(values.length).toBe(2);
    expect(keys[0].textContent).toBe("totalEvents");
    expect(values[0].textContent).toBe("42");
  });

  it("renders array data as formatted JSON in fallback mode", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "ArrayPlugin",
      componentName: "c-array-plugin",
      data: [{ severity: "ERROR", count: 5 }]
    };
    document.body.appendChild(element);
    await Promise.resolve();

    expect(
      element.shadowRoot.querySelector(".fallback-data-raw").textContent
    ).toContain("ERROR");
  });

  it("shows the no-data message when pluginData is null", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "EmptyPlugin",
      componentName: "c-empty-plugin",
      data: null
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const allSmallText = element.shadowRoot.querySelectorAll(
      ".slds-text-body_small"
    );
    const noDataEl = Array.from(allSmallText).find((node) =>
      node.textContent.includes("No data returned by this plugin")
    );

    expect(noDataEl).toBeDefined();
  });

  it("fetches plugin data by developerName when data is not provided", async () => {
    const getCardPluginData = require("@salesforce/apex/IntegrationHealthController.getCardPluginData");

    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.filters = { severity: "ERROR" };
    element.plugin = {
      developerName: "SeverityPlugin",
      name: "Severity",
      componentName: "c-ihd-severity-breakdown"
    };
    document.body.appendChild(element);

    await Promise.resolve();
    await Promise.resolve();

    expect(getCardPluginData.default).toHaveBeenCalledWith({
      pluginName: "SeverityPlugin",
      filters: { severity: "ERROR" }
    });
    expect(
      element.shadowRoot.querySelector(".fallback-data-value").textContent
    ).toBe("42");
  });

  it("accepts the filters property", () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    const testFilters = { dateRange: "7d", severity: "ERROR" };

    element.filters = testFilters;
    document.body.appendChild(element);

    expect(element.filters).toStrictEqual(testFilters);
  });
});
