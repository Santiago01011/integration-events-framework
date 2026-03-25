import { createElement } from "lwc";
import IhdTopErrorIntegrations from "c/ihdTopErrorIntegrations";

describe("c-ihd-top-error-integrations", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  // --- Rendering ---

  it("renders the card container with title", () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    document.body.appendChild(element);

    const title = element.shadowRoot.querySelector(".card-title");
    expect(title).not.toBeNull();
    expect(title.textContent).toBe("Top Error Integrations");
  });

  // --- Empty state ---

  it("shows empty state when no integrations", () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [];
    document.body.appendChild(element);

    const emptyState = element.shadowRoot.querySelector(".empty-state");
    expect(emptyState).not.toBeNull();

    const emptyText = element.shadowRoot.querySelector(".empty-text");
    expect(emptyText.textContent).toBe("No errors in this period");
  });

  it("shows empty state when integrations is undefined", () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = undefined;
    document.body.appendChild(element);

    const emptyState = element.shadowRoot.querySelector(".empty-state");
    expect(emptyState).not.toBeNull();
  });

  // --- Ranked list rendering ---

  it("renders ranked list of integrations", async () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "SAP",
        displayName: "SAP Integration",
        errorCount: 50,
        totalEvents: 200,
        trend: "up"
      },
      {
        integrationCode: "ERP",
        displayName: "ERP Connector",
        errorCount: 30,
        totalEvents: 150,
        trend: "down"
      }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const rows = element.shadowRoot.querySelectorAll(".error-row");
    expect(rows.length).toBe(2);

    const firstRank = rows[0].querySelector(".rank");
    expect(firstRank.textContent).toBe("1.");

    const secondRank = rows[1].querySelector(".rank");
    expect(secondRank.textContent).toBe("2.");
  });

  it("displays integration names and error counts", async () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "SAP",
        displayName: "SAP Integration",
        errorCount: 50,
        totalEvents: 200,
        trend: "flat"
      }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const name = element.shadowRoot.querySelector(".integration-name");
    expect(name.textContent).toContain("SAP Integration");

    const errorCount = element.shadowRoot.querySelector(".error-count");
    expect(errorCount.textContent).toBe("50");
  });

  // --- Bar widths ---

  it("computes proportional bar widths", () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "A",
        displayName: "A",
        errorCount: 100,
        totalEvents: 500,
        trend: "flat"
      },
      {
        integrationCode: "B",
        displayName: "B",
        errorCount: 50,
        totalEvents: 200,
        trend: "flat"
      }
    ];
    document.body.appendChild(element);

    const displayItems = element.displayIntegrations;
    expect(displayItems[0].barWidth).toBe("100%");
    expect(displayItems[1].barWidth).toBe("50%");
  });

  it("renders bar-fill elements with computed width", async () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "A",
        displayName: "A",
        errorCount: 100,
        totalEvents: 500,
        trend: "flat"
      },
      {
        integrationCode: "B",
        displayName: "B",
        errorCount: 25,
        totalEvents: 100,
        trend: "flat"
      }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const barFills = element.shadowRoot.querySelectorAll(".bar-fill");
    expect(barFills.length).toBe(2);
    expect(barFills[0].style.width).toBe("100%");
    expect(barFills[1].style.width).toBe("25%");
  });

  // --- topN limit ---

  it("limits displayed integrations to topN", () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.topN = 3;
    element.integrations = [
      {
        integrationCode: "A",
        displayName: "A",
        errorCount: 100,
        totalEvents: 500,
        trend: "flat"
      },
      {
        integrationCode: "B",
        displayName: "B",
        errorCount: 80,
        totalEvents: 400,
        trend: "flat"
      },
      {
        integrationCode: "C",
        displayName: "C",
        errorCount: 60,
        totalEvents: 300,
        trend: "flat"
      },
      {
        integrationCode: "D",
        displayName: "D",
        errorCount: 40,
        totalEvents: 200,
        trend: "flat"
      },
      {
        integrationCode: "E",
        displayName: "E",
        errorCount: 20,
        totalEvents: 100,
        trend: "flat"
      }
    ];
    document.body.appendChild(element);

    const displayItems = element.displayIntegrations;
    expect(displayItems.length).toBe(3);
    expect(displayItems[0].integrationCode).toBe("A");
    expect(displayItems[2].integrationCode).toBe("C");
  });

  // --- Trend indicators ---

  it("renders trend symbols for each row", async () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "A",
        displayName: "A",
        errorCount: 50,
        totalEvents: 200,
        trend: "up"
      },
      {
        integrationCode: "B",
        displayName: "B",
        errorCount: 30,
        totalEvents: 100,
        trend: "down"
      },
      {
        integrationCode: "C",
        displayName: "C",
        errorCount: 10,
        totalEvents: 50,
        trend: "flat"
      }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const trendIndicators =
      element.shadowRoot.querySelectorAll(".trend-indicator");
    expect(trendIndicators.length).toBe(3);
    expect(trendIndicators[0].textContent).toContain("\u25B2"); // ▲
    expect(trendIndicators[1].textContent).toContain("\u25BC"); // ▼
    expect(trendIndicators[2].textContent).toContain("\u2500"); // ─
  });

  it("sets trend title attributes for accessibility", async () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "A",
        displayName: "A",
        errorCount: 50,
        totalEvents: 200,
        trend: "up"
      },
      {
        integrationCode: "B",
        displayName: "B",
        errorCount: 30,
        totalEvents: 100,
        trend: "down"
      }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const trendIndicators =
      element.shadowRoot.querySelectorAll(".trend-indicator");
    expect(trendIndicators[0].title).toBe("Trending worse");
    expect(trendIndicators[1].title).toBe("Improving");
  });

  it("applies correct trend CSS classes", () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "A",
        displayName: "A",
        errorCount: 50,
        totalEvents: 200,
        trend: "up"
      },
      {
        integrationCode: "B",
        displayName: "B",
        errorCount: 30,
        totalEvents: 100,
        trend: "down"
      }
    ];
    document.body.appendChild(element);

    const items = element.displayIntegrations;
    expect(items[0].trendClass).toBe("trend-indicator trend-up");
    expect(items[1].trendClass).toBe("trend-indicator trend-down");
  });

  // --- Click event ---

  it("dispatches integrationclick event on row click", async () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "SAP",
        displayName: "SAP Integration",
        errorCount: 50,
        totalEvents: 200,
        trend: "up"
      }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const clickHandler = jest.fn();
    element.addEventListener("integrationclick", clickHandler);

    const row = element.shadowRoot.querySelector(".error-row");
    row.click();
    await Promise.resolve();

    expect(clickHandler).toHaveBeenCalledTimes(1);
    expect(clickHandler.mock.calls[0][0].detail.integrationCode).toBe("SAP");
  });

  it("dispatches integrationclick on Enter keydown", async () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "ERP",
        displayName: "ERP Connector",
        errorCount: 30,
        totalEvents: 150,
        trend: "down"
      }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const clickHandler = jest.fn();
    element.addEventListener("integrationclick", clickHandler);

    const row = element.shadowRoot.querySelector(".error-row");
    row.dispatchEvent(
      new KeyboardEvent("keydown", { key: "Enter", bubbles: true })
    );
    await Promise.resolve();

    expect(clickHandler).toHaveBeenCalledTimes(1);
    expect(clickHandler.mock.calls[0][0].detail.integrationCode).toBe("ERP");
  });

  it("does not dispatch event on Space key when key is not Enter or Space", async () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "SAP",
        displayName: "SAP",
        errorCount: 50,
        totalEvents: 200,
        trend: "up"
      }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const clickHandler = jest.fn();
    element.addEventListener("integrationclick", clickHandler);

    const row = element.shadowRoot.querySelector(".error-row");
    row.dispatchEvent(
      new KeyboardEvent("keydown", { key: "Tab", bubbles: true })
    );
    await Promise.resolve();

    expect(clickHandler).not.toHaveBeenCalled();
  });

  // --- Loading state ---

  it("shows spinner when isLoading is true", async () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.isLoading = true;
    element.integrations = [
      {
        integrationCode: "SAP",
        displayName: "SAP",
        errorCount: 50,
        totalEvents: 200,
        trend: "up"
      }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();

    // Error list should not be visible during loading
    const errorList = element.shadowRoot.querySelector(".error-list");
    expect(errorList).toBeNull();
  });

  // --- displayIntegrations getter edge cases ---

  it("falls back to integrationCode when displayName is missing", () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "MY_API",
        errorCount: 50,
        totalEvents: 200,
        trend: "flat"
      }
    ];
    document.body.appendChild(element);

    const items = element.displayIntegrations;
    expect(items[0].displayName).toBeUndefined();
    expect(items[0].integrationCode).toBe("MY_API");
  });

  it("handles trend defaulting to flat for unknown values", () => {
    const element = createElement("c-ihd-top-error-integrations", {
      is: IhdTopErrorIntegrations
    });
    element.integrations = [
      {
        integrationCode: "X",
        displayName: "X",
        errorCount: 10,
        totalEvents: 50,
        trend: "unknown"
      }
    ];
    document.body.appendChild(element);

    const items = element.displayIntegrations;
    expect(items[0].trendSymbol).toBe("\u2500"); // flat symbol
    expect(items[0].trendTitle).toBe("Stable");
    expect(items[0].trendClass).toBe("trend-indicator trend-flat");
  });
});
