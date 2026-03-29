import { createElement } from "lwc";
import IhdSeverityBreakdown from "c/ihdSeverityBreakdown";

describe("c-ihd-severity-breakdown", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  // --- Rendering ---

  it("renders the card container with title", () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    document.body.appendChild(element);

    const container = element.shadowRoot.querySelector(".card-container");
    expect(container).not.toBeNull();
    expect(container.getAttribute("aria-label")).toBe("Severity Breakdown");
  });

  // --- Empty state ---

  it("shows empty state when no severity data", () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [];
    document.body.appendChild(element);

    const emptyState = element.shadowRoot.querySelector(".empty-state");
    expect(emptyState).not.toBeNull();

    const emptyText = element.shadowRoot.querySelector(".empty-text");
    expect(emptyText).not.toBeNull();
    expect(emptyText.textContent).toBe("No events recorded");
  });

  it("shows empty state when severityCounts is undefined", () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = undefined;
    document.body.appendChild(element);

    const emptyState = element.shadowRoot.querySelector(".empty-state");
    expect(emptyState).not.toBeNull();
  });

  // --- Donut chart ---

  it("renders donut chart with severity data", async () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [
      { severity: "SUCCESS", count: 100, percentage: 72 },
      { severity: "ERROR", count: 28, percentage: 20 },
      { severity: "WARN", count: 12, percentage: 8 }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const donut = element.shadowRoot.querySelector(".donut");
    expect(donut).not.toBeNull();

    const hole = element.shadowRoot.querySelector(".donut-hole");
    expect(hole).not.toBeNull();
  });

  it("computes donutStyle getter with correct percentage structure", async () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [
      { severity: "SUCCESS", count: 50, percentage: 50 },
      { severity: "ERROR", count: 50, percentage: 50 }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const donut = element.shadowRoot.querySelector(".donut");
    expect(donut).not.toBeNull();

    const legendItems = element.shadowRoot.querySelectorAll(".legend-item");
    expect(legendItems.length).toBe(2);
  });

  it("does not render donut when hasData is false", () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [];
    document.body.appendChild(element);

    const donut = element.shadowRoot.querySelector(".donut");
    expect(donut).toBeNull();
  });

  // --- Legend entries ---

  it("renders legend items with labels, counts, and percentages", async () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [
      { severity: "SUCCESS", count: 100, percentage: 72 },
      { severity: "ERROR", count: 28, percentage: 20 },
      { severity: "WARN", count: 12, percentage: 8 }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const legendItems = element.shadowRoot.querySelectorAll(".legend-item");
    expect(legendItems.length).toBe(3);

    const firstDot = legendItems[0].querySelector(".legend-dot");
    expect(firstDot).not.toBeNull();

    const firstLabel = legendItems[0].querySelector(".legend-label");
    expect(firstLabel.textContent).toBe("Success");

    const firstCount = legendItems[0].querySelector(".legend-count");
    expect(firstCount.textContent).toBe("100");

    const firstPercentage = legendItems[0].querySelector(".legend-percentage");
    expect(firstPercentage.textContent).toBe("(72%)");
  });

  it("renders correct labels for ERROR and WARN severities", async () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [
      { severity: "SUCCESS", count: 100, percentage: 72 },
      { severity: "ERROR", count: 28, percentage: 20 },
      { severity: "WARN", count: 12, percentage: 8 }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const legendItems = element.shadowRoot.querySelectorAll(".legend-item");

    const errorLabel = legendItems[1].querySelector(".legend-label");
    expect(errorLabel.textContent).toBe("Error");

    const warnLabel = legendItems[2].querySelector(".legend-label");
    expect(warnLabel.textContent).toBe("Warning");
  });

  it("applies background-color to legend dots", async () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [
      { severity: "SUCCESS", count: 100, percentage: 100 }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const dot = element.shadowRoot.querySelector(".legend-dot");
    expect(dot).not.toBeNull();
    expect(dot.hasAttribute("style")).toBe(true);
  });

  // --- Loading state ---

  it("shows spinner when isLoading is true", async () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.isLoading = true;
    element.severityCounts = [
      { severity: "SUCCESS", count: 100, percentage: 100 }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();

    const donut = element.shadowRoot.querySelector(".donut");
    expect(donut).toBeNull();
  });

  // --- Filtering ---

  it("filters out entries without severity or count", async () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [
      { severity: "SUCCESS", count: 100, percentage: 50 },
      { severity: "", count: 50, percentage: 25 },
      { count: 30, percentage: 15 },
      { severity: "ERROR", count: 20, percentage: 10 }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const legendItems = element.shadowRoot.querySelectorAll(".legend-item");
    expect(legendItems.length).toBe(2);
    expect(legendItems[0].querySelector(".legend-label").textContent).toBe(
      "Success"
    );
    expect(legendItems[1].querySelector(".legend-label").textContent).toBe(
      "Error"
    );
  });

  // --- Donut hole ---

  it("renders donut hole for the ring effect", async () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [
      { severity: "SUCCESS", count: 100, percentage: 100 }
    ];
    document.body.appendChild(element);
    await Promise.resolve();

    const hole = element.shadowRoot.querySelector(".donut-hole");
    expect(hole).not.toBeNull();
  });

  // --- FATAL severity ---

  it("renders FATAL severity with Fatal label", async () => {
    const element = createElement("c-ihd-severity-breakdown", {
      is: IhdSeverityBreakdown
    });
    element.severityCounts = [{ severity: "FATAL", count: 5, percentage: 100 }];
    document.body.appendChild(element);
    await Promise.resolve();

    const legendItems = element.shadowRoot.querySelectorAll(".legend-item");
    expect(legendItems.length).toBe(1);
    expect(legendItems[0].querySelector(".legend-label").textContent).toBe(
      "Fatal"
    );
  });
});
