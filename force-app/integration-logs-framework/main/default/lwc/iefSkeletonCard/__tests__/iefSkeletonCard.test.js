import { createElement } from "lwc";
import IefSkeletonCard from "c/iefSkeletonCard";

describe("c-ief-skeleton-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders donut variant by default", () => {
    const element = createElement("c-ief-skeleton-card", {
      is: IefSkeletonCard
    });
    document.body.appendChild(element);

    const donutLayout = element.shadowRoot.querySelector(".donut-layout");
    expect(donutLayout).not.toBeNull();

    const skeletonDonut = element.shadowRoot.querySelector(".skeleton-donut");
    expect(skeletonDonut).not.toBeNull();

    // Donut variant should have legend stubs
    const legendStubs = element.shadowRoot.querySelectorAll(
      ".skeleton-legend-row"
    );
    expect(legendStubs.length).toBe(5);
  });

  it("renders donut variant when explicitly set", () => {
    const element = createElement("c-ief-skeleton-card", {
      is: IefSkeletonCard
    });
    element.variant = "donut";
    document.body.appendChild(element);

    const donutLayout = element.shadowRoot.querySelector(".donut-layout");
    expect(donutLayout).not.toBeNull();

    // Other variants should not render
    const listStubs = element.shadowRoot.querySelector(".list-stubs");
    expect(listStubs).toBeNull();
    const sparklineLayout =
      element.shadowRoot.querySelector(".sparkline-layout");
    expect(sparklineLayout).toBeNull();
  });

  it("renders list variant with title and item stubs", () => {
    const element = createElement("c-ief-skeleton-card", {
      is: IefSkeletonCard
    });
    element.variant = "list";
    document.body.appendChild(element);

    const skeletonTitle = element.shadowRoot.querySelector(".skeleton-title");
    expect(skeletonTitle).not.toBeNull();

    const listItems = element.shadowRoot.querySelectorAll(
      ".skeleton-list-item"
    );
    expect(listItems.length).toBe(5);

    // Donut should not render
    const donutLayout = element.shadowRoot.querySelector(".donut-layout");
    expect(donutLayout).toBeNull();
  });

  it("renders sparkline variant with bar and meta stubs", () => {
    const element = createElement("c-ief-skeleton-card", {
      is: IefSkeletonCard
    });
    element.variant = "sparkline";
    document.body.appendChild(element);

    const sparklineLayout =
      element.shadowRoot.querySelector(".sparkline-layout");
    expect(sparklineLayout).not.toBeNull();

    const skeletonSparkline = element.shadowRoot.querySelector(
      ".skeleton-sparkline"
    );
    expect(skeletonSparkline).not.toBeNull();

    const metaValue = element.shadowRoot.querySelector(".skeleton-meta-value");
    expect(metaValue).not.toBeNull();

    const metaLabel = element.shadowRoot.querySelector(".skeleton-meta-label");
    expect(metaLabel).not.toBeNull();

    // Donut should not render
    const donutLayout = element.shadowRoot.querySelector(".donut-layout");
    expect(donutLayout).toBeNull();
  });

  it("applies shimmer animation to skeleton elements", () => {
    const element = createElement("c-ief-skeleton-card", {
      is: IefSkeletonCard
    });
    document.body.appendChild(element);

    const skeletons = element.shadowRoot.querySelectorAll(".skeleton");
    expect(skeletons.length).toBeGreaterThan(0);

    // Each skeleton should have the CSS class that drives the animation
    skeletons.forEach((skeleton) => {
      expect(skeleton.classList.contains("skeleton")).toBe(true);
    });
  });

  it("renders skeleton-container wrapper", () => {
    const element = createElement("c-ief-skeleton-card", {
      is: IefSkeletonCard
    });
    document.body.appendChild(element);

    const container = element.shadowRoot.querySelector(".skeleton-container");
    expect(container).not.toBeNull();
  });
});
