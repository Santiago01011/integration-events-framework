import { createElement } from "lwc";
import IhdTrendIndicator from "c/ihdTrendIndicator";

describe("c-ihd-trend-indicator", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  // --- Rendering ---

  it("renders the trend container with title", () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    document.body.appendChild(element);

    const title = element.shadowRoot.querySelector(".trend-title");
    expect(title).not.toBeNull();
    expect(title.textContent).toBe("Hourly Trend");
  });

  // --- Empty state ---

  it("shows empty state when trendData is undefined", () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = undefined;
    document.body.appendChild(element);

    const emptyState = element.shadowRoot.querySelector(".empty-state");
    expect(emptyState).not.toBeNull();
    expect(emptyState.textContent).toContain("Not enough data for trend");
  });

  it("shows empty state when trendData has fewer than 2 points", () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [{ hour: "10:00", total: 50 }],
      direction: "flat",
      delta: 0
    };
    document.body.appendChild(element);

    const emptyState = element.shadowRoot.querySelector(".empty-state");
    expect(emptyState).not.toBeNull();
  });

  it("shows empty state when trendData.points is undefined", () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = { direction: "up", delta: 5 };
    document.body.appendChild(element);

    const emptyState = element.shadowRoot.querySelector(".empty-state");
    expect(emptyState).not.toBeNull();
  });

  // --- SVG sparkline ---

  it("renders SVG sparkline with trend data", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 50 },
        { hour: "11:00", total: 30 },
        { hour: "12:00", total: 40 }
      ],
      direction: "up",
      delta: 3.2
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const svg = element.shadowRoot.querySelector(".sparkline-svg");
    expect(svg).not.toBeNull();

    const polyline = svg.querySelector("polyline");
    expect(polyline).not.toBeNull();
    expect(polyline.getAttribute("points")).toBeTruthy();
    expect(polyline.getAttribute("fill")).toBe("none");
  });

  it("computes sparkline points and normalizes to viewBox", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 100 },
        { hour: "11:00", total: 0 }
      ],
      direction: "down",
      delta: -50
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const svg = element.shadowRoot.querySelector(".sparkline-svg");
    expect(svg).not.toBeNull();
    expect(svg.getAttribute("viewBox")).toBe("0 0 100 30");

    const polyline = svg.querySelector("polyline");
    const pointsAttr = polyline.getAttribute("points");
    expect(pointsAttr).not.toBeNull();

    const coords = pointsAttr.split(" ");
    expect(coords.length).toBe(2);
    expect(coords[0]).toBe("0,0");
    expect(coords[1]).toBe("100,30");
  });

  it("normalizes sparkline points for 3 data points", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 50 },
        { hour: "11:00", total: 50 },
        { hour: "12:00", total: 50 }
      ],
      direction: "flat",
      delta: 0
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const polyline = element.shadowRoot.querySelector("polyline");
    const pointsAttr = polyline.getAttribute("points");
    const coords = pointsAttr.split(" ");
    expect(coords.length).toBe(3);
    expect(coords[0]).toBe("0,0");
    expect(coords[1]).toBe("50,0");
    expect(coords[2]).toBe("100,0");
  });

  // --- Delta display ---

  it("renders delta with positive sign for up direction", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 10 },
        { hour: "11:00", total: 15 }
      ],
      direction: "up",
      delta: 3.2
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const deltaSection = element.shadowRoot.querySelector(".delta-section");
    expect(deltaSection).not.toBeNull();

    const deltaText = deltaSection.querySelector("span.delta-positive");
    expect(deltaText).not.toBeNull();
    expect(deltaText.textContent).toContain("+3.2% vs last hour");
  });

  it("renders delta without positive sign when negative", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 20 },
        { hour: "11:00", total: 10 }
      ],
      direction: "down",
      delta: -12
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const deltaText = element.shadowRoot.querySelector("span.delta-negative");
    expect(deltaText).not.toBeNull();
    expect(deltaText.textContent).toContain("-12% vs last hour");
  });

  it("renders delta as zero for flat trend", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 10 },
        { hour: "11:00", total: 10 }
      ],
      direction: "flat",
      delta: 0
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const deltaText = element.shadowRoot.querySelector("span.delta-flat");
    expect(deltaText).not.toBeNull();
    expect(deltaText.textContent).toContain("0% vs last hour");
  });

  it("shows '--' when delta is null", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 10 },
        { hour: "11:00", total: 10 }
      ],
      direction: "flat",
      delta: null
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const deltaText = element.shadowRoot.querySelector("span.delta-flat");
    expect(deltaText).not.toBeNull();
    expect(deltaText.textContent).toContain("--");
  });

  // --- Stroke color via DOM ---

  it("uses green stroke for positive trend (up)", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 10 },
        { hour: "11:00", total: 5 }
      ],
      direction: "up",
      delta: 5
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const polyline = element.shadowRoot.querySelector("polyline");
    expect(polyline.getAttribute("stroke")).toContain("success");
  });

  it("uses red stroke for negative trend (down)", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 5 },
        { hour: "11:00", total: 10 }
      ],
      direction: "down",
      delta: -5
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const polyline = element.shadowRoot.querySelector("polyline");
    expect(polyline.getAttribute("stroke")).toContain("error");
  });

  it("uses gray stroke for flat trend", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.trendData = {
      points: [
        { hour: "10:00", total: 10 },
        { hour: "11:00", total: 10 }
      ],
      direction: "flat",
      delta: 0
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const polyline = element.shadowRoot.querySelector("polyline");
    expect(polyline.getAttribute("stroke")).toContain("#747474");
  });

  // --- Label prop ---

  it("renders custom label when provided", async () => {
    const element = createElement("c-ihd-trend-indicator", {
      is: IhdTrendIndicator
    });
    element.label = "Total Events";
    element.trendData = {
      points: [
        { hour: "10:00", total: 10 },
        { hour: "11:00", total: 15 }
      ],
      direction: "up",
      delta: 5
    };
    document.body.appendChild(element);
    await Promise.resolve();

    const title = element.shadowRoot.querySelector(".trend-title");
    expect(title.textContent).toBe("Total Events");
  });
});
