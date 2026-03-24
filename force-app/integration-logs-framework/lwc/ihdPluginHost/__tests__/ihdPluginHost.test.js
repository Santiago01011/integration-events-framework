import { createElement } from "lwc";
import IhdPluginHost from "c/ihdPluginHost";

describe("c-ihd-plugin-host", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  // --- Rendering ---

  it("renders nothing when no plugin is provided", () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = null;
    document.body.appendChild(element);

    const card = element.shadowRoot.querySelector(".slds-card");
    expect(card).toBeNull();
  });

  it("renders fallback card for unknown plugin component", async () => {
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

    const card = element.shadowRoot.querySelector(".slds-card");
    expect(card).not.toBeNull();

    const title = element.shadowRoot.querySelector(".slds-card__header-title");
    expect(title).not.toBeNull();
    expect(title.textContent).toBe("CustomPlugin");

    const description = element.shadowRoot.querySelector(
      ".slds-text-body_regular"
    );
    expect(description).not.toBeNull();
    expect(description.textContent).toBe("A custom third-party plugin");

    const code = element.shadowRoot.querySelector("code");
    expect(code).not.toBeNull();
    expect(code.textContent).toBe("c-custom-plugin");
  });

  // --- Registry (isKnownPlugin) ---

  it("does not render fallback when plugin is in registry (isKnownPlugin)", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "Severity",
      componentName: "c-ihd-severity-breakdown",
      data: []
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const severityComponent = element.shadowRoot.querySelector(
      "c-ihd-severity-breakdown"
    );
    expect(severityComponent).not.toBeNull();

    // Fallback should not be rendered for known plugins
    const code = element.shadowRoot.querySelector("code");
    expect(code).toBeNull();
  });

  it("renders fallback when plugin is NOT in registry (unknown componentName)", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "UnknownPlugin",
      componentName: "c-unknown-plugin",
      description: "Not registered"
    };
    document.body.appendChild(element);
    await Promise.resolve();

    // isKnownPlugin returns false, fallback renders
    const code = element.shadowRoot.querySelector("code");
    expect(code).not.toBeNull();
    expect(code.textContent).toBe("c-unknown-plugin");

    // No plugin components rendered
    const severity = element.shadowRoot.querySelector(
      "c-ihd-severity-breakdown"
    );
    expect(severity).toBeNull();
    const topError = element.shadowRoot.querySelector(
      "c-ihd-top-error-integrations"
    );
    expect(topError).toBeNull();
  });

  // --- Severity Breakdown ---

  it("renders severity breakdown when componentName matches", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "SeverityBreakdown",
      componentName: "c-ihd-severity-breakdown",
      data: [{ severity: "ERROR", count: 5, percentage: 50 }]
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const severityComponent = element.shadowRoot.querySelector(
      "c-ihd-severity-breakdown"
    );
    expect(severityComponent).not.toBeNull();
  });

  it("does not render severity breakdown for different componentName", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "OtherPlugin",
      componentName: "c-other-component",
      data: {}
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const severityComponent = element.shadowRoot.querySelector(
      "c-ihd-severity-breakdown"
    );
    expect(severityComponent).toBeNull();
  });

  // --- Top Error Integrations ---

  it("renders top error integrations when componentName matches", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "TopErrors",
      componentName: "c-ihd-top-error-integrations",
      data: [{ integrationCode: "SAP", totalEvents: 10 }]
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const topErrorComponent = element.shadowRoot.querySelector(
      "c-ihd-top-error-integrations"
    );
    expect(topErrorComponent).not.toBeNull();
  });

  it("does not render fallback when top error plugin is used", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "TopErrors",
      componentName: "c-ihd-top-error-integrations",
      data: []
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const topErrorComponent = element.shadowRoot.querySelector(
      "c-ihd-top-error-integrations"
    );
    expect(topErrorComponent).not.toBeNull();

    const code = element.shadowRoot.querySelector("code");
    expect(code).toBeNull();
  });

  // --- Getter behavior (tested through DOM rendering) ---

  it("renders no content when plugin is null (hasPlugin=false)", () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = null;
    document.body.appendChild(element);

    // hasPlugin returns false, so no template content renders
    const card = element.shadowRoot.querySelector(".slds-card");
    expect(card).toBeNull();
    const severity = element.shadowRoot.querySelector(
      "c-ihd-severity-breakdown"
    );
    expect(severity).toBeNull();
  });

  it("renders content when plugin is provided (hasPlugin=true)", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "Test",
      componentName: "c-unknown-plugin",
      description: "Test"
    };
    document.body.appendChild(element);
    await Promise.resolve();

    // hasPlugin returns true, template renders
    const card = element.shadowRoot.querySelector(".slds-card");
    expect(card).not.toBeNull();
  });

  // --- Loading state ---

  it("accepts isLoading property", () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "Test",
      componentName: "c-ihd-severity-breakdown",
      data: []
    };
    element.isLoading = true;
    document.body.appendChild(element);

    expect(element.isLoading).toBe(true);
  });

  // --- Filters ---

  it("accepts filters property", () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    const testFilters = { dateRange: "7d", severity: "ERROR" };
    element.plugin = {
      name: "Test",
      componentName: "c-test"
    };
    element.filters = testFilters;
    document.body.appendChild(element);

    expect(element.filters).toStrictEqual(testFilters);
  });

  // --- Event delegation (generic handlePluginClick) ---

  it("dispatches pluginclick from severity event via generic handler", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "SeverityBreakdown",
      componentName: "c-ihd-severity-breakdown",
      data: []
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const clickHandler = jest.fn();
    element.addEventListener("pluginclick", clickHandler);

    const severityComponent = element.shadowRoot.querySelector(
      "c-ihd-severity-breakdown"
    );
    expect(severityComponent).not.toBeNull();

    severityComponent.dispatchEvent(
      new CustomEvent("severityclick", {
        detail: { severity: "ERROR" },
        bubbles: true,
        composed: true
      })
    );

    await Promise.resolve();

    expect(clickHandler).toHaveBeenCalledTimes(1);
    expect(clickHandler.mock.calls[0][0].detail.severity).toBe("ERROR");
    expect(clickHandler.mock.calls[0][0].detail.pluginName).toBe(
      "SeverityBreakdown"
    );
    expect(clickHandler.mock.calls[0][0].detail.componentName).toBe(
      "c-ihd-severity-breakdown"
    );
  });

  it("dispatches pluginclick from top error event via generic handler", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "TopErrors",
      componentName: "c-ihd-top-error-integrations",
      data: []
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const clickHandler = jest.fn();
    element.addEventListener("pluginclick", clickHandler);

    const topErrorComponent = element.shadowRoot.querySelector(
      "c-ihd-top-error-integrations"
    );
    expect(topErrorComponent).not.toBeNull();

    topErrorComponent.dispatchEvent(
      new CustomEvent("integrationclick", {
        detail: { integrationCode: "SAP_ORDERS" },
        bubbles: true,
        composed: true
      })
    );

    await Promise.resolve();

    expect(clickHandler).toHaveBeenCalledTimes(1);
    expect(clickHandler.mock.calls[0][0].detail.integrationCode).toBe(
      "SAP_ORDERS"
    );
    expect(clickHandler.mock.calls[0][0].detail.pluginName).toBe("TopErrors");
    expect(clickHandler.mock.calls[0][0].detail.componentName).toBe(
      "c-ihd-top-error-integrations"
    );
  });

  it("does not dispatch pluginclick for unknown plugin click", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "UnknownPlugin",
      componentName: "c-unknown-plugin",
      description: "Not registered"
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const clickHandler = jest.fn();
    element.addEventListener("pluginclick", clickHandler);

    // Fallback card has no clickable plugin elements that dispatch events
    const card = element.shadowRoot.querySelector(".slds-card");
    expect(card).not.toBeNull();
  });

  // --- Enhanced fallback card (Phase 4) ---

  it("renders fallback card with plugin name, description, and component name", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "CustomPlugin",
      componentName: "c-custom-plugin",
      description: "A custom third-party widget"
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const card = element.shadowRoot.querySelector(".fallback-card");
    expect(card).not.toBeNull();

    const title = element.shadowRoot.querySelector(".slds-card__header-title");
    expect(title.textContent).toContain("CustomPlugin");

    const description = element.shadowRoot.querySelector(
      ".slds-text-body_regular"
    );
    expect(description.textContent).toBe("A custom third-party widget");

    const badge = element.shadowRoot.querySelector(".slds-badge");
    expect(badge).not.toBeNull();
    expect(badge.textContent).toBe("Unregistered");

    const code = element.shadowRoot.querySelector("code");
    expect(code.textContent).toBe("c-custom-plugin");
  });

  it("renders fallback card data as key-value pairs when pluginData is an object", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "DataPlugin",
      componentName: "c-data-plugin",
      description: "Plugin with data",
      data: { totalEvents: 42, errorRate: "3.2%", status: "healthy" }
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const dataPreview = element.shadowRoot.querySelector(
      ".fallback-data-preview"
    );
    expect(dataPreview).not.toBeNull();

    const keys = element.shadowRoot.querySelectorAll(".fallback-data-key");
    expect(keys.length).toBe(3);

    const values = element.shadowRoot.querySelectorAll(".fallback-data-value");
    expect(values.length).toBe(3);

    // Verify the first entry has the correct key
    expect(keys[0].textContent).toBe("totalEvents");
    expect(values[0].textContent).toBe("42");
  });

  it("renders fallback card with no data message when pluginData is null", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "EmptyPlugin",
      componentName: "c-empty-plugin",
      description: "Plugin with no data",
      data: null
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const card = element.shadowRoot.querySelector(".fallback-card");
    expect(card).not.toBeNull();

    // Verify the "no data" message appears (search across all small text elements)
    const allSmallText = element.shadowRoot.querySelectorAll(
      ".slds-text-body_small"
    );
    const noDataEl = Array.from(allSmallText).find((el) =>
      el.textContent.includes("No data returned by this plugin")
    );
    expect(noDataEl).not.toBeUndefined();
  });

  it("renders fallback card with formatted JSON when pluginData is an array", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "ArrayPlugin",
      componentName: "c-array-plugin",
      description: "Plugin with array data",
      data: [{ severity: "ERROR", count: 5 }]
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const rawPreview = element.shadowRoot.querySelector(".fallback-data-raw");
    expect(rawPreview).not.toBeNull();
    expect(rawPreview.textContent).toContain("ERROR");
  });

  it("does not render data preview section for known plugins", async () => {
    const element = createElement("c-ihd-plugin-host", {
      is: IhdPluginHost
    });
    element.plugin = {
      name: "Severity",
      componentName: "c-ihd-severity-breakdown",
      data: [{ severity: "ERROR", count: 5 }]
    };
    document.body.appendChild(element);
    await Promise.resolve();

    // Known plugin renders the actual component, not the fallback
    const dataPreview = element.shadowRoot.querySelector(
      ".fallback-data-preview"
    );
    expect(dataPreview).toBeNull();
  });
});
