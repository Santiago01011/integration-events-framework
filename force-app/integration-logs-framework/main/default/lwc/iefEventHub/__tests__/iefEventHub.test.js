import { createElement } from "lwc";
import IefEventHub from "c/iefEventHub";
import logsApi from "c/utilsLogsApi";

jest.mock(
  "c/utilsLogsApi",
  () => {
    return {
      __esModule: true,
      default: {
        initRealtime: jest.fn(),
        unsubscribeFromLogs: jest.fn(),
        transformEventToRow: jest.fn((e, typeToSeverity, normalizeFn) => {
          const type = (e.ObservationType__c || "").toUpperCase();
          const severity = typeToSeverity[type] || "INFO";
          const icon = severity === "ERROR" ? "utility:error" : "utility:info";
          return {
            IntegrationCode__c: e.IntegrationCode__c,
            Normalized_Context__c: normalizeFn(e.IntegrationCode__c),
            ObservationType__c: e.ObservationType__c,
            Context__c: e.Context__c,
            statusIconName: icon,
            _severity: severity
          };
        }),
        showToast: jest.fn()
      }
    };
  },
  { virtual: true }
);

describe("c-ief-event-hub", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("should initialize realtime connection on connectedCallback", () => {
    const element = createElement("c-ief-event-hub", {
      is: IefEventHub
    });
    document.body.appendChild(element);

    expect(logsApi.initRealtime).toHaveBeenCalled();
  });

  it("should process and flush single event with meaningful toast", () => {
    jest.useFakeTimers();
    const element = createElement("c-ief-event-hub", {
      is: IefEventHub
    });
    element.summaries = [
      { integrationCode: "SAP", displayName: "SAP Integration" }
    ];
    element.typeToSeverity = { ERROR: "ERROR" };
    document.body.appendChild(element);

    // Get the callback passed to initRealtime
    const onEventCallback = logsApi.initRealtime.mock.calls[0][1];

    // Simulate new event
    onEventCallback({
      IntegrationCode__c: "SAP",
      ObservationType__c: "ERROR",
      Context__c: "Connection Timeout"
    });

    // Fast-forward timers
    jest.runAllTimers();

    expect(logsApi.showToast).toHaveBeenCalledWith(
      expect.anything(),
      "New integration event",
      "SAP",
      "error"
    );
    jest.useRealTimers();
  });

  it("should process multiple events as a pulse", () => {
    jest.useFakeTimers();
    const element = createElement("c-ief-event-hub", {
      is: IefEventHub
    });
    document.body.appendChild(element);

    const onEventCallback = logsApi.initRealtime.mock.calls[0][1];

    onEventCallback({ IntegrationCode__c: "A" });
    onEventCallback({ IntegrationCode__c: "B" });

    jest.runAllTimers();

    expect(logsApi.showToast).toHaveBeenCalledWith(
      expect.anything(),
      "IEF Pulse",
      "2 integration events received",
      "info"
    );
    jest.useRealTimers();
  });
});
