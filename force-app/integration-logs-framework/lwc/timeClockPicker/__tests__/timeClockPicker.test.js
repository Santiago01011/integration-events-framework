import { createElement } from "lwc";
import TimeClockPicker from "c/timeClockPicker";

describe("c-time-clock-picker", () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("displays default time 00:00 when no value is provided", () => {
    const element = createElement("c-time-clock-picker", {
      is: TimeClockPicker
    });
    document.body.appendChild(element);

    // Verify input value
    const input = element.shadowRoot.querySelector("input");
    expect(input.value).toBe("00:00");
  });

  it("opens popover on click", async () => {
    const element = createElement("c-time-clock-picker", {
      is: TimeClockPicker
    });
    document.body.appendChild(element);

    const input = element.shadowRoot.querySelector("input");
    input.click();

    // Wait for re-render
    await Promise.resolve();

    const popover = element.shadowRoot.querySelector(".tcp-popover-custom");
    expect(popover).not.toBeNull();
  });

  it("renders correct number of hour dots in 24h mode", async () => {
    const element = createElement("c-time-clock-picker", {
      is: TimeClockPicker
    });
    element.hourMode = 24;
    document.body.appendChild(element);

    const input = element.shadowRoot.querySelector("input");
    input.click();
    await Promise.resolve();

    const dots = element.shadowRoot.querySelectorAll(".tcp-dot");
    // 0-23 hours = 24 dots
    expect(dots.length).toBe(24);
  });

  it("updates value when time is applied", async () => {
    const element = createElement("c-time-clock-picker", {
      is: TimeClockPicker
    });
    document.body.appendChild(element);

    const input = element.shadowRoot.querySelector("input");
    input.click();
    await Promise.resolve();
    const hour10Btn = element.shadowRoot.querySelector(
      'button[data-value="10"]'
    );
    expect(hour10Btn).not.toBeNull();
    hour10Btn.click();

    await Promise.resolve();
    const applyBtn = element.shadowRoot.querySelector(
      ".slds-popover__footer button.slds-button_brand"
    );
    applyBtn.click();

    await Promise.resolve();
    expect(element.value).toBe("10:00");
  });

  it("clears value when clear button is clicked", async () => {
    const element = createElement("c-time-clock-picker", {
      is: TimeClockPicker
    });
    element.value = "15:30";
    document.body.appendChild(element);

    const input = element.shadowRoot.querySelector("input");
    input.click();
    await Promise.resolve();

    const buttons = Array.from(
      element.shadowRoot.querySelectorAll(".slds-popover__footer button")
    );
    const clearButton = buttons.find((b) => b.textContent === "Clear");

    clearButton.click();
    await Promise.resolve();

    expect(element.value).toBe("");
  });
});
