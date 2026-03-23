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

  it("does not render fallback when severity plugin is used", async () => {
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
  // Note: pluginName, pluginData, hasPlugin are private getters (not @api),
  // so they are tested indirectly through their effect on rendered output.

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

  // --- Event delegation ---

  it("dispatches pluginclick from severity click handler", async () => {
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
  });

  it("dispatches pluginclick from top error click handler", async () => {
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
  });
});
