import { LightningElement, api, track, wire } from "lwc";
import { publish, MessageContext } from "lightning/messageService";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import IEF_PLUGIN_ACTIONS from "@salesforce/messageChannel/IEF_Plugin_Actions__c";
import getLiveSessionTrace from "@salesforce/apex/AgentforceLiveQueryController.getLiveSessionTrace";
import getRecentSessionIds from "@salesforce/apex/AgentforceLiveQueryController.getRecentSessionIds";
import getRecentLogs from "@salesforce/apex/IntegrationHealthController.getRecentLogs";
import getLogDetail from "@salesforce/apex/IntegrationHealthController.getLogDetail";

const FETCH_SIZE = 80;
const MAX_SESSIONS = 12;
const MAX_EVENTS_PER_SESSION = 60;
const NO_CORRELATION_KEY = "NO_CORRELATION";
const ERROR_SEVERITIES = new Set(["ERROR", "FATAL"]);
const WARNING_SEVERITIES = new Set(["WARN", "WARNING"]);
const LLM_STEP_TYPES = new Set(["LLM", "LLM_STEP", "GENERATION"]);
const ACTION_STEP_TYPES = new Set(["ACTION", "FUNCTION", "TOOL"]);
const GUARDRAIL_STEP_TYPES = new Set(["GUARDRAIL", "SAFETY"]);
const TRACE_SECTION_KEYS = [
  "agentforcePayload",
  "agentforceData",
  "sessionPayload",
  "tracePayload",
  "debugPayload"
];

export default class IefAgentforceCoreCardImpl extends LightningElement {
  _contextData = "";

  @api isDeveloperMode = false;

  liveSessionId = "";
  isLiveQueryDisabled = true;
  recentSessions = [];

  @wire(MessageContext)
  messageContext;

  @wire(getRecentSessionIds)
  wiredRecentSessions({ error, data }) {
    if (data) {
      this.recentSessions = data;
    } else if (error) {
      console.error("Error fetching recent session IDs", error);
    }
  }

  parsedContext = null;

  @track isLoading = true;
  @track hasError = false;
  @track errorIsAccessDenied = false;
  @track errorMessage = "";
  @track sessionRows = [];
  @track selectedSessionKey = "";
  @track selectedEventId = "";
  @track selectedEventDetail = null;
  @track isEventDetailLoading = false;
  @track totalSessions = 0;
  @track totalEvents = 0;
  @track totalErrors = 0;
  @track totalWarnings = 0;
  @track totalUncorrelatedEvents = 0;
  @track lastRefreshLabel = "";
  @track queryPreview = "";
  @track queryBundlePreview = "";
  @track showQueryInspector = false;
  @track dataMode = "integration-log";

  connectedCallback() {
    this._parseAndFetch();
  }

  @api
  set contextData(value) {
    this._contextData = value;
    if (this.isConnected) {
      this._parseAndFetch();
    }
  }

  get contextData() {
    return this._contextData;
  }

  get cardTitle() {
    return this.dataMode === "session-payload"
      ? "Agentforce Session Debugger"
      : "Agentforce Core Pulse";
  }

  get hasSessions() {
    return this.sessionRows.length > 0;
  }

  get hasSelectedSession() {
    return this.selectedSession !== null;
  }

  get selectedSession() {
    if (!this.selectedSessionKey) {
      return null;
    }
    return (
      this.sessionRows.find(
        (row) => row.correlationId === this.selectedSessionKey
      ) || null
    );
  }

  get selectedSessionEvents() {
    const session = this.selectedSession;
    return session ? session.events : [];
  }

  get selectedSessionTitle() {
    const session = this.selectedSession;
    return session ? session.displayCorrelation : "No Session Selected";
  }

  get selectedSessionSubtitle() {
    const session = this.selectedSession;
    if (!session) {
      return "Choose a session to inspect timeline and payloads";
    }
    return `${session.totalEvents} events · ${session.llmCalls} llm · ${session.actionCalls} actions · ${session.totalTokenCount} tk`;
  }

  get selectedSessionAgentName() {
    const session = this.selectedSession;
    return session?.agentName || "Unknown Agent";
  }

  get selectedSessionLlmModel() {
    const session = this.selectedSession;
    return session?.llmModel || "n/a";
  }

  get selectedSessionDurationLabel() {
    const session = this.selectedSession;
    if (!session || !session.startedAtEpoch || !session.endedAtEpoch) {
      return "-";
    }
    const diff = Math.max(0, session.endedAtEpoch - session.startedAtEpoch);
    const totalSeconds = Math.floor(diff / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}m ${seconds}s`;
  }

  get selectedSessionTurnCount() {
    const session = this.selectedSession;
    return session ? session.totalEvents : 0;
  }

  get selectedSessionLlmCalls() {
    const session = this.selectedSession;
    return session ? session.llmCalls : 0;
  }

  get selectedSessionActionCalls() {
    const session = this.selectedSession;
    return session ? session.actionCalls : 0;
  }

  get selectedSessionGuardrailChecks() {
    const session = this.selectedSession;
    return session ? session.guardrailChecks : 0;
  }

  get selectedSessionProcessingLabel() {
    const session = this.selectedSession;
    return session ? `${session.totalProcessingMs} ms` : "-";
  }

  get selectedSessionTokenLabel() {
    const session = this.selectedSession;
    return session ? `${session.totalTokenCount.toLocaleString()} tk` : "-";
  }

  get selectedSessionTopicsLabel() {
    const session = this.selectedSession;
    if (!session || !session.topicNames.length) {
      return "No topics";
    }
    return session.topicNames.join(", ");
  }

  get reasoningSteps() {
    const events = this.selectedSessionEvents;
    return events
      .filter((event) => {
        const stepType = String(event.reasoningStepType || "").toUpperCase();
        return (
          LLM_STEP_TYPES.has(stepType) ||
          ACTION_STEP_TYPES.has(stepType) ||
          GUARDRAIL_STEP_TYPES.has(stepType)
        );
      })
      .map((event, idx) => {
        const stepType = event.reasoningStepType || "Step";
        const stepName = event.reasoningStepName || `${stepType} ${idx + 1}`;
        const rawInput = event.rawInput || "";
        const rawOutput = event.rawOutput || "";
        return {
          ...event,
          stepType,
          stepName,
          hasInput: rawInput !== "" && rawInput !== "No data",
          hasOutput: rawOutput !== "" && rawOutput !== "No data"
        };
      });
  }

  get hasReasoningSteps() {
    return this.reasoningSteps.length > 0;
  }

  get selectedEvent() {
    const eventId = this.selectedEventId;
    if (!eventId) {
      return null;
    }
    const events = this.selectedSessionEvents;
    return events.find((event) => event.id === eventId) || null;
  }

  get selectedEventOccurredLabel() {
    const event = this.selectedEvent;
    return event ? event.occurredAtLabel : "-";
  }

  get selectedEventSeverity() {
    const event = this.selectedEvent;
    return event ? event.severityLabel : "-";
  }

  get selectedEventObservation() {
    const event = this.selectedEvent;
    return event ? event.observationType : "-";
  }

  get selectedEventIntegrationCode() {
    const event = this.selectedEvent;
    return event ? event.integrationCode : "-";
  }

  get selectedEventHttpStatus() {
    const event = this.selectedEvent;
    return event && event.httpStatus ? event.httpStatus : "-";
  }

  get selectedEventDuration() {
    const event = this.selectedEvent;
    return event && event.duration !== null && event.duration !== undefined
      ? `${event.duration} ms`
      : "-";
  }

  get detailContextPretty() {
    return this._getPrettyPayload(this._getDetailRecord()?.Context__c);
  }

  get detailPromptContextPretty() {
    return this._getPrettyPayload(this._getDetailRecord()?.PromptContext__c);
  }

  get detailRequestPretty() {
    return this._getPrettyPayload(this._getDetailRecord()?.Request_Body__c);
  }

  get detailResponsePretty() {
    return this._getPrettyPayload(this._getDetailRecord()?.Response_Body__c);
  }

  get detailToolInvocationsPretty() {
    return this._getPrettyPayload(this._getDetailRecord()?.ToolInvocations__c);
  }

  get detailRawInputPretty() {
    return this._getPrettyPayload(this._getDetailRecord()?.RawInput__c);
  }

  get detailRawOutputPretty() {
    return this._getPrettyPayload(this._getDetailRecord()?.RawOutput__c);
  }

  get detailAgentName() {
    return this._getDetailRecord()?.AgentName__c || "-";
  }

  get detailAgentSessionId() {
    return this._getDetailRecord()?.AgentSessionId__c || "-";
  }

  get detailConversationId() {
    return this._getDetailRecord()?.ConversationId__c || "-";
  }

  get detailLlmModel() {
    return this._getDetailRecord()?.LlmModel__c || "-";
  }

  get detailReasoningStepType() {
    return this._getDetailRecord()?.ReasoningStepType__c || "-";
  }

  get detailReasoningStepName() {
    return this._getDetailRecord()?.ReasoningStepName__c || "-";
  }

  get detailTopicName() {
    return this._getDetailRecord()?.TopicName__c || "-";
  }

  get detailPromptTokens() {
    const value = this._getDetailRecord()?.PromptTokens__c;
    return value || value === 0 ? String(value) : "-";
  }

  get detailCompletionTokens() {
    const value = this._getDetailRecord()?.CompletionTokens__c;
    return value || value === 0 ? String(value) : "-";
  }

  get detailTotalTokens() {
    const value = this._getDetailRecord()?.TotalTokens__c;
    return value || value === 0 ? String(value) : "-";
  }

  get detailProcessingTime() {
    const value = this._getDetailRecord()?.ProcessingTimeMs__c;
    return value || value === 0 ? `${value} ms` : "-";
  }

  get detailPersistDebugDetail() {
    const value = this._getDetailRecord()?.PersistDebugDetail__c;
    return value === true ? "Yes" : "No";
  }

  get detailStepTokenInfo() {
    const record = this._getDetailRecord();
    if (!record?.StepTokenInfo__c) return null;
    return record.StepTokenInfo__c;
  }

  get detailStepModel() {
    const info = this.detailStepTokenInfo;
    return info?.model || this._getDetailRecord()?.LlmModel__c || "-";
  }

  get detailStepProvider() {
    const info = this.detailStepTokenInfo;
    return info?.provider || "-";
  }

  get detailStepPromptTokens() {
    const info = this.detailStepTokenInfo;
    return info?.promptTokens != null
      ? String(info.promptTokens)
      : this.detailPromptTokens;
  }

  get detailStepCompletionTokens() {
    const info = this.detailStepTokenInfo;
    return info?.completionTokens != null
      ? String(info.completionTokens)
      : this.detailCompletionTokens;
  }

  get detailStepTotalTokens() {
    const info = this.detailStepTokenInfo;
    return info?.totalTokens != null
      ? String(info.totalTokens)
      : this.detailTotalTokens;
  }

  get detailStepTemperature() {
    const info = this.detailStepTokenInfo;
    return info?.temperature != null ? String(info.temperature) : "-";
  }

  get detailGatewayRequestId() {
    const record = this._getDetailRecord();
    return record?.GatewayRequestId__c || "-";
  }

  get detailGatewayResponseId() {
    const record = this._getDetailRecord();
    return record?.GatewayResponseId__c || "-";
  }

  get detailGenerationId() {
    const record = this._getDetailRecord();
    return record?.GenerationId__c || "-";
  }

  get detailTraceSpanId() {
    const record = this._getDetailRecord();
    return record?.TraceSpanId__c || "-";
  }

  get detailPromptTemplateName() {
    const info = this.detailStepTokenInfo;
    if (!info?.promptTemplateName) return "-";
    return String(info.promptTemplateName).replace(/"/g, "");
  }

  get detailParsedMessages() {
    const event = this.selectedEvent;
    if (!event) return [];
    return this._extractMessagesFromInput(event.rawInput);
  }

  get detailParsedTools() {
    const event = this.selectedEvent;
    if (!event) return [];
    return this._extractToolsFromInput(event.rawInput);
  }

  get detailParsedToolInvocations() {
    const event = this.selectedEvent;
    if (!event) return [];
    return this._extractToolInvocationsFromOutput(event.rawOutput);
  }

  get detailParsedLlmResponse() {
    const event = this.selectedEvent;
    if (!event) return "";
    return this._extractLlmResponse(event.rawOutput);
  }

  get detailParsedActionInput() {
    const event = this.selectedEvent;
    if (!event) return [];
    const decoded = this._decodeTraceText(event.rawInput);
    try {
      const parsed = JSON.parse(decoded);
      const input = parsed?.actionInput;
      if (!input || typeof input !== "object") return [];
      return Object.entries(input).map(([k, v], i) => ({
        id: "ap-" + i,
        key: k,
        value: String(v)
      }));
    } catch {
      return [];
    }
  }

  get detailParsedActionResponse() {
    const event = this.selectedEvent;
    if (!event) return null;
    return this._extractActionResponse(event.rawOutput);
  }

  get detailActionName() {
    const event = this.selectedEvent;
    if (!event) return "";
    const decoded = this._decodeTraceText(event.rawInput);
    try {
      const parsed = JSON.parse(decoded);
      const name = parsed?.actionName || "";
      return name.replace(/_[a-f0-9]{15,}$/i, "").replace(/_/g, " ");
    } catch {
      return "";
    }
  }

  get detailIsLlmStep() {
    const event = this.selectedEvent;
    if (!event) return false;
    const stepType = String(event.reasoningStepType || "").toUpperCase();
    return LLM_STEP_TYPES.has(stepType);
  }

  get detailIsActionStep() {
    const event = this.selectedEvent;
    if (!event) return false;
    const stepType = String(event.reasoningStepType || "").toUpperCase();
    return ACTION_STEP_TYPES.has(stepType);
  }

  get detailErrorText() {
    const event = this.selectedEvent;
    if (!event) return "";
    return event.errorText || "";
  }

  get detailHasTokenData() {
    return this.detailStepTokenInfo != null;
  }

  get detailPreStepVars() {
    const record = this._getDetailRecord();
    if (!record?.PreStepVariables__c) return "";
    return this._getPrettyPayload(record.PreStepVariables__c);
  }

  get detailPostStepVars() {
    const record = this._getDetailRecord();
    if (!record?.PostStepVariables__c) return "";
    return this._getPrettyPayload(record.PostStepVariables__c);
  }

  get detailStepPromptFull() {
    const info = this.detailStepTokenInfo;
    if (!info?.prompt) return "";
    const decoded = info.prompt
      .replace(/\\n/g, "\n")
      .replace(/\\"/g, '"')
      .replace(/\\t/g, "\t")
      .replace(/\\\\/g, "\\");
    return decoded;
  }

  get hasSelectedEvent() {
    return this.selectedEvent !== null;
  }

  get activeFilterChips() {
    const filters = this.parsedContext?.filters || {};
    const chips = [];

    const mappings = [
      ["search", "Search"],
      ["observationType", "Observation"],
      ["integrationCode", "Integration"],
      ["correlationId", "Correlation"],
      ["fromOccurredAt", "From"],
      ["toOccurredAt", "To"]
    ];

    for (const [key, label] of mappings) {
      const value = filters[key];
      if (typeof value === "string" && value.trim() !== "") {
        chips.push({ key, label, value: value.trim() });
      }
    }

    return chips;
  }

  get hasActiveFilterChips() {
    return this.activeFilterChips.length > 0;
  }

  get filterSummary() {
    const activeCount = this._countActiveFilters();
    return activeCount > 0
      ? `Active filters: ${activeCount}`
      : "No active dashboard filters";
  }

  get queryToggleIcon() {
    return this.showQueryInspector ? "utility:close" : "utility:filterList";
  }

  get queryToggleVariant() {
    return this.showQueryInspector ? "brand" : "neutral";
  }

  get queryToggleAriaExpanded() {
    return this.showQueryInspector ? "true" : "false";
  }

  _parseAndFetch() {
    this._parseContextData();
    if (!this.hasError) {
      this._fetchData();
    }
  }

  _parseContextData() {
    this.hasError = false;
    this.errorMessage = "";

    if (!this.contextData || this.contextData === "") {
      this.parsedContext = { filters: {} };
      return;
    }

    try {
      this.parsedContext = JSON.parse(this.contextData);
      if (!this.parsedContext.filters) {
        this.parsedContext.filters = {};
      }
    } catch {
      this.hasError = true;
      this.errorMessage = "Invalid context data received";
      this.parsedContext = { filters: {} };
    }
  }

  async _fetchData() {
    this.isLoading = true;
    this.hasError = false;
    this.errorIsAccessDenied = false;
    this.selectedEventDetail = null;

    try {
      const filters = this.parsedContext?.filters || {};
      const sessionPayload = this._extractSessionPayload(this.parsedContext);

      if (sessionPayload) {
        const summary = this._summarizeSessionPayload(sessionPayload, filters);
        await this._applySummary(summary, filters, true);
        return;
      }

      const page = await getRecentLogs({
        pageSize: FETCH_SIZE,
        search: filters.search || null,
        fromOccurredAtStr: filters.fromOccurredAt || null,
        toOccurredAtStr: filters.toOccurredAt || null,
        lastOccurredAtStr: null,
        lastId: null,
        correlationId: filters.correlationId || null,
        observationType: filters.observationType || null,
        integrationCode: filters.integrationCode || null
      });

      const records = Array.isArray(page?.records) ? page.records : [];
      const severityMap = page?.typeToSeverity || {};
      const summary = this._summarizeSessions(records, severityMap);
      await this._applySummary(summary, filters, false);
    } catch (error) {
      const isAccessError = this._isAccessError(error);
      this.hasError = true;
      this.errorIsAccessDenied = isAccessError;
      this.errorMessage = isAccessError
        ? "Persistence layer not accessible. Assign the Ief_AgentforceCore_Execute permission set, or load a session JSON file to use session-payload mode."
        : error?.body?.message || "Failed to load session pulse";
      this.sessionRows = [];
      this.totalSessions = 0;
      this.totalEvents = 0;
      this.totalErrors = 0;
      this.totalWarnings = 0;
      this.totalUncorrelatedEvents = 0;
      this.queryPreview = "";
      this.queryBundlePreview = "";
      this.selectedSessionKey = "";
      this.selectedEventId = "";
    } finally {
      this.isLoading = false;
    }
  }

  async _applySummary(summary, filters, isSessionPayloadMode) {
    this.dataMode = isSessionPayloadMode
      ? "session-payload"
      : "integration-log";
    this.sessionRows = summary.rows;
    this.totalSessions = summary.totalSessions;
    this.totalEvents = summary.totalEvents;
    this.totalErrors = summary.totalErrors;
    this.totalWarnings = summary.totalWarnings;
    this.totalUncorrelatedEvents = summary.totalUncorrelatedEvents;
    this.lastRefreshLabel = this._formatTimestamp(Date.now());
    this.queryPreview = this._buildQueryPreview(filters, isSessionPayloadMode);
    this.queryBundlePreview = this._buildQueryBundlePreview(
      filters,
      isSessionPayloadMode
    );

    if (this.sessionRows.length > 0) {
      this.selectedSessionKey = this.sessionRows[0].correlationId;
      const firstEvent = this.sessionRows[0].events[0];
      this.selectedEventId = firstEvent ? firstEvent.id : "";
      if (this.selectedEventId) {
        await this._loadEventDetail(this.selectedEventId);
      }
    } else {
      this.selectedSessionKey = "";
      this.selectedEventId = "";
    }
  }

  _extractSessionPayload(parsedContext) {
    if (!parsedContext || typeof parsedContext !== "object") {
      return null;
    }

    if (
      parsedContext.session &&
      parsedContext.conversation &&
      parsedContext.trace
    ) {
      return parsedContext;
    }

    for (const key of TRACE_SECTION_KEYS) {
      const value = parsedContext[key];
      if (
        value &&
        typeof value === "object" &&
        value.session &&
        value.conversation &&
        value.trace
      ) {
        return value;
      }
    }

    return null;
  }

  _summarizeSessionPayload(payload, filters) {
    const sessionData = payload?.session || {};
    const traceData = payload?.trace || {};
    const conversation = payload?.conversation || {};
    const interactions = Array.isArray(traceData.interactions)
      ? traceData.interactions
      : [];
    const steps = Array.isArray(traceData.steps) ? traceData.steps : [];
    const entries = Array.isArray(conversation.entries)
      ? conversation.entries
      : [];

    const interactionById = new Map();
    for (const interaction of interactions) {
      const id = interaction?.ssot__Id__c;
      if (id) {
        interactionById.set(id, interaction);
      }
    }

    const correlationId =
      String(
        sessionData?.Id || traceData?.dcSessionId || NO_CORRELATION_KEY
      ).trim() || NO_CORRELATION_KEY;

    const events = [];

    for (const step of steps) {
      const stepTypeRaw = String(
        step?.ssot__AiAgentInteractionStepType__c || "STEP"
      );
      const interactionId = step?.ssot__AiAgentInteractionId__c;
      const interaction = interactionById.get(interactionId) || null;
      const startedAt = this._normalizeTimestamp(step?.ssot__StartTimestamp__c);
      const endedAt = this._normalizeTimestamp(step?.ssot__EndTimestamp__c);
      const occurredAt =
        startedAt ||
        endedAt ||
        this._normalizeTimestamp(sessionData?.StartTime);
      const processingTimeMs = this._safeDurationMs(startedAt, endedAt);

      const inputPayload = this._decodeTraceText(step?.ssot__InputValueText__c);
      const outputPayload = this._decodeTraceText(
        step?.ssot__OutputValueText__c
      );
      const attrPayload = this._decodeTraceText(step?.ssot__AttributeText__c);
      const isError =
        String(step?.ssot__ErrorMessageText__c || "").toUpperCase() !==
          "NOT_SET" &&
        String(step?.ssot__ErrorMessageText__c || "").trim() !== "";
      const severity = isError ? "ERROR" : "INFO";

      const parsedOutput = this._tryParseJson(outputPayload);
      const toolInvocations = parsedOutput?.toolInvocations || [];

      const promptTokens = Number(step?.ssot__PromptTokens__c || 0);
      const completionTokens = Number(step?.ssot__CompletionTokens__c || 0);
      const totalTokens =
        Number(step?.ssot__TotalTokens__c || 0) ||
        (promptTokens > 0 || completionTokens > 0
          ? promptTokens + completionTokens
          : 0);

      const eventId =
        String(step?.ssot__Id__c || "").trim() ||
        `${interactionId || "step"}-${events.length + 1}`;
      const topicName =
        interaction?.ssot__TopicApiName__c &&
        interaction?.ssot__TopicApiName__c !== "NOT_SET"
          ? interaction.ssot__TopicApiName__c
          : "";

      const gatewayRequestId =
        step?.ssot__GenAiGatewayRequestId__c &&
        step.ssot__GenAiGatewayRequestId__c !== "NOT_SET"
          ? step.ssot__GenAiGatewayRequestId__c
          : null;
      const gatewayResponseId =
        step?.ssot__GenAiGatewayResponseId__c &&
        step.ssot__GenAiGatewayResponseId__c !== "NOT_SET"
          ? step.ssot__GenAiGatewayResponseId__c
          : null;
      const generationId =
        step?.ssot__GenerationId__c && step.ssot__GenerationId__c !== "NOT_SET"
          ? step.ssot__GenerationId__c
          : null;
      const traceSpanId = step?.ssot__AttributeText__c
        ? this._extractTraceSpanId(step.ssot__AttributeText__c)
        : null;
      const tokenData = traceData?.tokenData || {};
      const stepTokenInfo = gatewayRequestId
        ? tokenData[gatewayRequestId] || null
        : null;
      const preStepVars =
        step?.ssot__PreStepVariableText__c &&
        step.ssot__PreStepVariableText__c !== "NOT_SET"
          ? step.ssot__PreStepVariableText__c
          : null;
      const postStepVars =
        step?.ssot__PostStepVariableText__c &&
        step.ssot__PostStepVariableText__c !== "NOT_SET"
          ? step.ssot__PostStepVariableText__c
          : null;

      const detailRecord = {
        AgentName__c: sessionData?.Name || "Agentforce Session",
        AgentSessionId__c: traceData?.dcSessionId || sessionData?.Id || null,
        ConversationId__c:
          sessionData?.ConversationId || conversation?.uuid || null,
        LlmModel__c: stepTokenInfo?.model || step?.ssot__ModelName__c || "-",
        ReasoningStepType__c: stepTypeRaw,
        ReasoningStepName__c: step?.ssot__Name__c || stepTypeRaw,
        TopicName__c: topicName || "-",
        PromptTokens__c: promptTokens,
        CompletionTokens__c: completionTokens,
        TotalTokens__c: totalTokens,
        ProcessingTimeMs__c: processingTimeMs,
        PersistDebugDetail__c: true,
        PromptContext__c: inputPayload,
        Context__c: attrPayload,
        ToolInvocations__c: this._stringify(toolInvocations),
        Request_Body__c: inputPayload,
        Response_Body__c: outputPayload,
        RawInput__c: inputPayload,
        RawOutput__c: outputPayload,
        GatewayRequestId__c: gatewayRequestId,
        GatewayResponseId__c: gatewayResponseId,
        GenerationId__c: generationId,
        TraceSpanId__c: traceSpanId,
        StepTokenInfo__c: stepTokenInfo,
        PreStepVariables__c: preStepVars,
        PostStepVariables__c: postStepVars
      };

      events.push({
        id: eventId,
        observationType: stepTypeRaw,
        integrationCode:
          interaction?.ssot__AiAgentInteractionType__c || "TRACE",
        occurredAtRaw: occurredAt,
        occurredAtLabel: this._formatTimestamp(occurredAt),
        severity,
        severityLabel: severity,
        severityClass: this._getSeverityBadgeClass(severity),
        correlationId,
        agentName: sessionData?.Name || "Agentforce Session",
        agentSessionId: traceData?.dcSessionId || sessionData?.Id || null,
        conversationId:
          sessionData?.ConversationId || conversation?.uuid || null,
        llmModel: detailRecord.LlmModel__c,
        reasoningStepType: stepTypeRaw,
        reasoningStepName: step?.ssot__Name__c || stepTypeRaw,
        topicName,
        promptTokens,
        completionTokens,
        totalTokens,
        processingTimeMs,
        promptContext: this._getPrettyPayload(inputPayload),
        toolInvocations: this._getPrettyPayload(
          detailRecord.ToolInvocations__c
        ),
        rawInput: this._getPrettyPayload(inputPayload),
        rawOutput: this._getPrettyPayload(outputPayload),
        responseBody: this._getPrettyPayload(outputPayload),
        httpStatus: null,
        duration: processingTimeMs,
        detailRecord,
        gatewayRequestId,
        gatewayResponseId,
        generationId,
        traceSpanId,
        stepTokenInfo,
        preStepVars,
        postStepVars,
        errorText: isError
          ? this._extractErrorMessage(step.ssot__ErrorMessageText__c)
          : ""
      });
    }

    for (const entry of entries) {
      const occurredAt =
        this._normalizeTimestamp(entry?.serverReceivedTimestamp) ||
        this._normalizeTimestamp(entry?.clientTimestamp);
      const role = entry?.sender?.role || "Unknown";
      const observationType =
        role === "EndUser" ? "USER_MESSAGE" : "BOT_MESSAGE";

      const detailRecord = {
        AgentName__c: entry?.sender?.subject || role,
        AgentSessionId__c: traceData?.dcSessionId || sessionData?.Id || null,
        ConversationId__c:
          sessionData?.ConversationId || conversation?.uuid || null,
        LlmModel__c: "-",
        ReasoningStepType__c: observationType,
        ReasoningStepName__c: role,
        TopicName__c: "Conversation",
        PromptTokens__c: 0,
        CompletionTokens__c: 0,
        TotalTokens__c: 0,
        ProcessingTimeMs__c: 0,
        PersistDebugDetail__c: true,
        PromptContext__c: this._stringify(entry),
        Context__c: this._stringify(entry?.sender || {}),
        ToolInvocations__c: "[]",
        Request_Body__c: this._stringify({
          messageText: entry?.messageText || ""
        }),
        Response_Body__c: this._stringify({ role }),
        RawInput__c: entry?.messageText || "",
        RawOutput__c: ""
      };

      events.push({
        id: String(entry?.identifier || `${role}-${events.length + 1}`),
        observationType,
        integrationCode: "CONVERSATION",
        occurredAtRaw: occurredAt,
        occurredAtLabel: this._formatTimestamp(occurredAt),
        severity: "INFO",
        severityLabel: "INFO",
        severityClass: this._getSeverityBadgeClass("INFO"),
        correlationId,
        agentName: detailRecord.AgentName__c,
        agentSessionId: detailRecord.AgentSessionId__c,
        conversationId: detailRecord.ConversationId__c,
        llmModel: "-",
        reasoningStepType: observationType,
        reasoningStepName: role,
        topicName: "Conversation",
        promptTokens: 0,
        completionTokens: 0,
        totalTokens: 0,
        processingTimeMs: 0,
        promptContext: this._getPrettyPayload(detailRecord.PromptContext__c),
        toolInvocations: "[]",
        rawInput: this._getPrettyPayload(detailRecord.RawInput__c),
        rawOutput: this._getPrettyPayload(detailRecord.RawOutput__c),
        responseBody: this._getPrettyPayload(detailRecord.Response_Body__c),
        httpStatus: null,
        duration: 0,
        detailRecord
      });
    }

    events.sort((a, b) => {
      const aDate = a.occurredAtRaw ? Date.parse(a.occurredAtRaw) : -Infinity;
      const bDate = b.occurredAtRaw ? Date.parse(b.occurredAtRaw) : -Infinity;
      return bDate - aDate;
    });

    const filteredEvents = events.filter((item) =>
      this._matchesFilters(item, filters)
    );

    let errorEvents = 0;
    let warningEvents = 0;
    let llmCalls = 0;
    let actionCalls = 0;
    let guardrailChecks = 0;
    let totalTokenCount = 0;
    let totalProcessingMs = 0;
    let startedAtEpoch = null;
    let endedAtEpoch = null;
    const integrationCodes = new Set();
    const topicNames = new Set();

    for (const event of filteredEvents) {
      if (ERROR_SEVERITIES.has(event.severity)) {
        errorEvents += 1;
      }
      if (WARNING_SEVERITIES.has(event.severity)) {
        warningEvents += 1;
      }
      const stepType = String(event.reasoningStepType || "").toUpperCase();
      if (LLM_STEP_TYPES.has(stepType)) {
        llmCalls += 1;
      }
      if (ACTION_STEP_TYPES.has(stepType)) {
        actionCalls += 1;
      }
      if (GUARDRAIL_STEP_TYPES.has(stepType)) {
        guardrailChecks += 1;
      }
      totalTokenCount += Number(event.totalTokens || 0);
      totalProcessingMs += Number(event.processingTimeMs || 0);
      if (event.integrationCode && event.integrationCode !== "Unknown") {
        integrationCodes.add(event.integrationCode);
      }
      if (event.topicName && event.topicName !== "-") {
        topicNames.add(event.topicName);
      }
      const occurredEpoch = Date.parse(event.occurredAtRaw || "");
      if (!Number.isNaN(occurredEpoch)) {
        startedAtEpoch =
          startedAtEpoch === null
            ? occurredEpoch
            : Math.min(startedAtEpoch, occurredEpoch);
        endedAtEpoch =
          endedAtEpoch === null
            ? occurredEpoch
            : Math.max(endedAtEpoch, occurredEpoch);
      }
    }

    const row = {
      correlationId,
      displayCorrelation: this._formatCorrelationId(correlationId),
      isSelected: true,
      totalEvents: filteredEvents.length,
      errorEvents,
      warningEvents,
      llmCalls,
      actionCalls,
      guardrailChecks,
      totalTokenCount,
      totalProcessingMs,
      agentName: sessionData?.Name || "Agentforce Session",
      llmModel: "Model by step",
      topicNames: Array.from(topicNames),
      startedAtEpoch,
      endedAtEpoch,
      integrationCount: integrationCodes.size,
      isDisabled: correlationId === NO_CORRELATION_KEY,
      lastOccurredAtEpoch: endedAtEpoch || -1,
      lastOccurredAtLabel: this._formatTimestamp(endedAtEpoch),
      errorClass:
        errorEvents > 0 ? "metric metric-error" : "metric metric-neutral",
      warningClass:
        warningEvents > 0 ? "metric metric-warning" : "metric metric-neutral",
      events: filteredEvents.slice(0, MAX_EVENTS_PER_SESSION)
    };

    return {
      rows: filteredEvents.length > 0 ? [row] : [],
      totalSessions: filteredEvents.length > 0 ? 1 : 0,
      totalEvents: filteredEvents.length,
      totalErrors: errorEvents,
      totalWarnings: warningEvents,
      totalUncorrelatedEvents:
        correlationId === NO_CORRELATION_KEY ? filteredEvents.length : 0
    };
  }

  _summarizeSessions(records, typeToSeverity) {
    const grouped = new Map();

    for (const record of records) {
      const correlationIdRaw = (record?.CorrelationId__c || "").trim();
      const correlationId =
        correlationIdRaw === "" ? NO_CORRELATION_KEY : correlationIdRaw;

      if (!grouped.has(correlationId)) {
        grouped.set(correlationId, {
          correlationId,
          totalEvents: 0,
          errorEvents: 0,
          warningEvents: 0,
          llmCalls: 0,
          actionCalls: 0,
          guardrailChecks: 0,
          totalTokenCount: 0,
          totalProcessingMs: 0,
          agentName: null,
          llmModel: null,
          topicNames: new Set(),
          startedAtEpoch: null,
          endedAtEpoch: null,
          lastOccurredAtRaw: null,
          lastOccurredAtEpoch: -1,
          integrationCodes: new Set(),
          events: []
        });
      }

      const current = grouped.get(correlationId);
      current.totalEvents += 1;

      const observationType = (record?.ObservationType__c || "").toUpperCase();
      const severity = String(
        typeToSeverity[observationType] || ""
      ).toUpperCase();
      if (ERROR_SEVERITIES.has(severity)) {
        current.errorEvents += 1;
      }
      if (WARNING_SEVERITIES.has(severity)) {
        current.warningEvents += 1;
      }

      const integrationCode = (record?.IntegrationCode__c || "").trim();
      if (integrationCode !== "") {
        current.integrationCodes.add(integrationCode);
      }

      const occurredAt = record?.OccurredAt__c || record?.CreatedDate || null;

      const eventId = record?.Id || "";
      const stepType = String(record?.ReasoningStepType__c || "").toUpperCase();
      if (LLM_STEP_TYPES.has(stepType)) {
        current.llmCalls += 1;
      }
      if (ACTION_STEP_TYPES.has(stepType)) {
        current.actionCalls += 1;
      }
      if (GUARDRAIL_STEP_TYPES.has(stepType)) {
        current.guardrailChecks += 1;
      }

      const totalTokens = Number(record?.TotalTokens__c || 0);
      const processingTime = Number(record?.ProcessingTimeMs__c || 0);
      current.totalTokenCount += totalTokens > 0 ? totalTokens : 0;
      current.totalProcessingMs += processingTime > 0 ? processingTime : 0;

      const topic = String(record?.TopicName__c || "").trim();
      if (topic) {
        current.topicNames.add(topic);
      }

      if (!current.agentName && record?.AgentName__c) {
        current.agentName = record.AgentName__c;
      }
      if (!current.llmModel && record?.LlmModel__c) {
        current.llmModel = record.LlmModel__c;
      }

      current.events.push({
        id: eventId,
        observationType: record?.ObservationType__c || "Unknown",
        integrationCode: integrationCode || "Unknown",
        occurredAtRaw: occurredAt,
        occurredAtLabel: this._formatTimestamp(occurredAt),
        severity: severity || "UNKNOWN",
        severityLabel: severity || "UNKNOWN",
        severityClass: this._getSeverityBadgeClass(severity),
        correlationId,
        agentName: record?.AgentName__c || null,
        agentSessionId: record?.AgentSessionId__c || null,
        conversationId: record?.ConversationId__c || null,
        llmModel: record?.LlmModel__c || null,
        reasoningStepType: record?.ReasoningStepType__c || null,
        reasoningStepName: record?.ReasoningStepName__c || null,
        topicName: record?.TopicName__c || null,
        promptTokens: Number(record?.PromptTokens__c || 0),
        completionTokens: Number(record?.CompletionTokens__c || 0),
        totalTokens,
        processingTimeMs: processingTime,
        promptContext: this._getPrettyPayload(record?.PromptContext__c),
        toolInvocations: this._getPrettyPayload(record?.ToolInvocations__c),
        rawInput: this._getPrettyPayload(record?.RawInput__c),
        rawOutput: this._getPrettyPayload(record?.RawOutput__c),
        responseBody: this._getPrettyPayload(record?.Response_Body__c),
        httpStatus: record?.HttpStatus__c || null,
        duration: record?.Duration__c || null
      });

      const occurredAtEpoch = occurredAt ? Date.parse(occurredAt) : -1;
      if (occurredAtEpoch > 0) {
        current.startedAtEpoch =
          current.startedAtEpoch === null
            ? occurredAtEpoch
            : Math.min(current.startedAtEpoch, occurredAtEpoch);
        current.endedAtEpoch =
          current.endedAtEpoch === null
            ? occurredAtEpoch
            : Math.max(current.endedAtEpoch, occurredAtEpoch);
      }
      if (occurredAtEpoch > current.lastOccurredAtEpoch) {
        current.lastOccurredAtEpoch = occurredAtEpoch;
        current.lastOccurredAtRaw = occurredAt;
      }
    }

    const unsortedRows = Array.from(grouped.values()).map((entry) => {
      const hasCorrelation = entry.correlationId !== NO_CORRELATION_KEY;
      entry.events.sort(
        (a, b) =>
          Date.parse(b.occurredAtRaw || 0) - Date.parse(a.occurredAtRaw || 0)
      );
      return {
        correlationId: entry.correlationId,
        displayCorrelation: this._formatCorrelationId(entry.correlationId),
        isSelected: this.selectedSessionKey === entry.correlationId,
        totalEvents: entry.totalEvents,
        errorEvents: entry.errorEvents,
        warningEvents: entry.warningEvents,
        llmCalls: entry.llmCalls,
        actionCalls: entry.actionCalls,
        guardrailChecks: entry.guardrailChecks,
        totalTokenCount: entry.totalTokenCount,
        totalProcessingMs: entry.totalProcessingMs,
        agentName: entry.agentName,
        llmModel: entry.llmModel,
        topicNames: Array.from(entry.topicNames),
        startedAtEpoch: entry.startedAtEpoch,
        endedAtEpoch: entry.endedAtEpoch,
        integrationCount: entry.integrationCodes.size,
        isDisabled: !hasCorrelation,
        lastOccurredAtEpoch: entry.lastOccurredAtEpoch,
        lastOccurredAtLabel: this._formatTimestamp(entry.lastOccurredAtRaw),
        errorClass:
          entry.errorEvents > 0
            ? "metric metric-error"
            : "metric metric-neutral",
        warningClass:
          entry.warningEvents > 0
            ? "metric metric-warning"
            : "metric metric-neutral",
        events: entry.events.slice(0, MAX_EVENTS_PER_SESSION)
      };
    });

    unsortedRows.sort((a, b) => b.lastOccurredAtEpoch - a.lastOccurredAtEpoch);

    const totals = unsortedRows.reduce(
      (acc, row) => {
        acc.totalEvents += row.totalEvents;
        acc.totalErrors += row.errorEvents;
        acc.totalWarnings += row.warningEvents;
        return acc;
      },
      {
        totalEvents: 0,
        totalErrors: 0,
        totalWarnings: 0
      }
    );

    return {
      rows: unsortedRows.slice(0, MAX_SESSIONS),
      totalSessions: unsortedRows.length,
      totalEvents: totals.totalEvents,
      totalErrors: totals.totalErrors,
      totalWarnings: totals.totalWarnings,
      totalUncorrelatedEvents: grouped.get(NO_CORRELATION_KEY)?.totalEvents || 0
    };
  }

  _getSeverityBadgeClass(severity) {
    if (ERROR_SEVERITIES.has(severity)) {
      return "severity severity-error";
    }
    if (WARNING_SEVERITIES.has(severity)) {
      return "severity severity-warning";
    }
    if (severity === "SUCCESS") {
      return "severity severity-success";
    }
    if (severity === "INFO") {
      return "severity severity-info";
    }
    return "severity severity-neutral";
  }

  _isAccessError(error) {
    const msg = String(
      error?.body?.message || error?.message || ""
    ).toUpperCase();
    return (
      msg.includes("INSUFFICIENT_ACCESS") ||
      msg.includes("FIELD_INTEGRITY_EXCEPTION") ||
      msg.includes("NO_ACCESS") ||
      error?.body?.errorCode === "INSUFFICIENT_ACCESS_OR_READONLY"
    );
  }

  _buildQueryPreview(filters, isSessionPayloadMode) {
    if (isSessionPayloadMode) {
      return [
        "SELECT Id, Name, Status, ConversationId, StartTime, EndTime",
        "FROM MessagingSession",
        "WHERE Id = '<session-id>'",
        "",
        "SELECT ssot__Id__c, ssot__AiAgentInteractionStepType__c, ssot__StartTimestamp__c, ssot__EndTimestamp__c",
        "FROM ssot__AiAgentStep__dlm",
        "WHERE ssot__AiAgentSessionId__c = '<dc-session-id>'",
        "ORDER BY ssot__StartTimestamp__c DESC"
      ].join("\n");
    }

    const clauses = [
      "SELECT Id, CorrelationId__c, ObservationType__c, IntegrationCode__c, OccurredAt__c, Duration__c, HttpStatus__c, AgentName__c, ReasoningStepType__c, TotalTokens__c, ProcessingTimeMs__c",
      "FROM Integration_Log__c"
    ];
    const where = [];

    if (filters.search) {
      where.push(
        `(ObservationType__c LIKE '%${this._escapeValue(filters.search)}%' OR IntegrationCode__c LIKE '%${this._escapeValue(filters.search)}%' OR CorrelationId__c LIKE '%${this._escapeValue(filters.search)}%')`
      );
    }
    if (filters.correlationId) {
      where.push(
        `CorrelationId__c = '${this._escapeValue(filters.correlationId)}'`
      );
    }
    if (filters.observationType) {
      where.push(
        `ObservationType__c = '${this._escapeValue(filters.observationType)}'`
      );
    }
    if (filters.integrationCode) {
      where.push(
        `IntegrationCode__c LIKE '%${this._escapeValue(filters.integrationCode)}%'`
      );
    }
    if (filters.fromOccurredAt) {
      where.push(`OccurredAt__c >= ${filters.fromOccurredAt}`);
    }
    if (filters.toOccurredAt) {
      where.push(`OccurredAt__c <= ${filters.toOccurredAt}`);
    }

    if (where.length) {
      clauses.push(`WHERE ${where.join(" AND ")}`);
    }
    clauses.push("ORDER BY OccurredAt__c DESC");
    clauses.push(`LIMIT ${FETCH_SIZE}`);

    return clauses.join("\n");
  }

  _buildQueryBundlePreview(filters, isSessionPayloadMode) {
    if (isSessionPayloadMode) {
      return [
        "-- Extension-style bundle",
        "1) MessagingSession + Conversation entries",
        "2) Data Cloud interactions by ssot__AiAgentSessionId__c",
        "3) Interaction steps ordered by ssot__StartTimestamp__c",
        "4) Stitch by ssot__AiAgentInteractionId__c for full timeline"
      ].join("\n");
    }

    const correlation = this.selectedSessionKey || "<session-correlation>";
    const sessionQuery = [
      "-- Session-level view (extension-style)",
      "SELECT CorrelationId__c, AgentSessionId__c, ConversationId__c, AgentName__c, LlmModel__c,",
      "       COUNT(Id), MIN(OccurredAt__c), MAX(OccurredAt__c)",
      "FROM Integration_Log__c",
      `WHERE CorrelationId__c = '${this._escapeValue(correlation)}'`,
      "GROUP BY CorrelationId__c, AgentSessionId__c, ConversationId__c, AgentName__c, LlmModel__c"
    ].join("\n");

    const stepsQuery = [
      "-- Reasoning steps timeline",
      "SELECT Id, OccurredAt__c, ObservationType__c, ReasoningStepType__c, ReasoningStepName__c,",
      "       TopicName__c, PromptTokens__c, CompletionTokens__c, TotalTokens__c, ProcessingTimeMs__c",
      "FROM Integration_Log__c",
      `WHERE CorrelationId__c = '${this._escapeValue(correlation)}'`,
      "ORDER BY OccurredAt__c ASC",
      `LIMIT ${MAX_EVENTS_PER_SESSION}`
    ].join("\n");

    const base = this._buildQueryPreview(filters);
    return [base, "", sessionQuery, "", stepsQuery].join("\n");
  }

  _escapeValue(value) {
    return String(value).replace(/'/g, "\\'");
  }

  _formatCorrelationId(correlationId) {
    if (correlationId === NO_CORRELATION_KEY) {
      return "No Correlation Id";
    }
    if (correlationId.length <= 22) {
      return correlationId;
    }
    return `${correlationId.slice(0, 14)}...${correlationId.slice(-6)}`;
  }

  _formatTimestamp(rawValue) {
    if (!rawValue) {
      return "Unknown";
    }
    const date = new Date(rawValue);
    if (Number.isNaN(date.getTime())) {
      return "Unknown";
    }
    return new Intl.DateTimeFormat(undefined, {
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit"
    }).format(date);
  }

  _countActiveFilters() {
    const filters = this.parsedContext?.filters || {};
    const keys = [
      "search",
      "observationType",
      "integrationCode",
      "correlationId",
      "fromOccurredAt",
      "toOccurredAt"
    ];

    let count = 0;
    for (const key of keys) {
      const value = filters[key];
      if (typeof value === "string" && value.trim() !== "") {
        count += 1;
      }
    }
    return count;
  }

  async _loadEventDetail(logId) {
    if (!logId) {
      this.selectedEventDetail = null;
      return;
    }

    if (this.dataMode === "session-payload") {
      const eventRow =
        this.selectedSessionEvents.find((entry) => entry.id === logId) || null;
      this.selectedEventDetail = eventRow
        ? { record: eventRow.detailRecord || {} }
        : null;
      return;
    }

    this.isEventDetailLoading = true;
    try {
      const detail = await getLogDetail({ logId });
      this.selectedEventDetail = detail || null;
    } catch {
      this.selectedEventDetail = null;
    } finally {
      this.isEventDetailLoading = false;
    }
  }

  _getPrettyPayload(value) {
    if (!value || String(value).trim() === "") {
      return "No data";
    }
    try {
      return JSON.stringify(JSON.parse(value), null, 2);
    } catch {
      return value;
    }
  }

  _getDetailRecord() {
    return (
      this.selectedEventDetail?.record ||
      this.selectedEvent?.detailRecord ||
      null
    );
  }

  _normalizeTimestamp(rawValue) {
    if (rawValue === null || rawValue === undefined || rawValue === "") {
      return null;
    }
    if (typeof rawValue === "number") {
      const date = new Date(rawValue);
      return Number.isNaN(date.getTime()) ? null : date.toISOString();
    }
    if (typeof rawValue === "string" && /^\d+$/.test(rawValue.trim())) {
      const asNumber = Number(rawValue);
      const date = new Date(asNumber);
      return Number.isNaN(date.getTime()) ? rawValue : date.toISOString();
    }
    return rawValue;
  }

  _safeDurationMs(startedAt, endedAt) {
    if (!startedAt || !endedAt) {
      return 0;
    }
    const startEpoch = Date.parse(startedAt);
    const endEpoch = Date.parse(endedAt);
    if (Number.isNaN(startEpoch) || Number.isNaN(endEpoch)) {
      return 0;
    }
    return Math.max(0, endEpoch - startEpoch);
  }

  _decodeTraceText(rawValue) {
    const value = String(rawValue || "").trim();
    if (value === "" || value.toUpperCase() === "NOT_SET") {
      return "";
    }
    return value
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">");
  }

  _tryParseJson(rawValue) {
    if (!rawValue) {
      return null;
    }
    try {
      return JSON.parse(rawValue);
    } catch {
      return null;
    }
  }

  _stringify(value) {
    try {
      return JSON.stringify(value, null, 2);
    } catch {
      return String(value || "");
    }
  }

  _extractTraceSpanId(attrText) {
    if (!attrText || attrText === "NOT_SET") return null;
    try {
      const decoded = this._decodeTraceText(attrText);
      const parsed = JSON.parse(decoded);
      return parsed.internalTraceId || null;
    } catch {
      return null;
    }
  }

  _decodeAndParsePayload(rawValue) {
    if (!rawValue || rawValue === "NOT_SET") return null;
    const decoded = this._decodeTraceText(rawValue);
    try {
      return JSON.parse(decoded);
    } catch {
      return null;
    }
  }

  _extractMessagesFromInput(inputPayload) {
    if (!inputPayload) return [];
    const decoded = this._decodeTraceText(inputPayload);
    try {
      const parsed = JSON.parse(decoded);
      const msgs = Array.isArray(parsed?.messages) ? parsed.messages : [];
      return msgs.map((m, i) => ({
        ...m,
        id: "msg-" + i,
        roleClass: "msg-role-badge role-" + (m.role || "unknown")
      }));
    } catch {
      return [];
    }
  }

  _extractToolsFromInput(inputPayload) {
    if (!inputPayload) return [];
    const decoded = this._decodeTraceText(inputPayload);
    try {
      const parsed = JSON.parse(decoded);
      const tools = Array.isArray(parsed?.tools) ? parsed.tools : [];
      return tools.map((t, i) => {
        const fn = t.function || {};
        const props = fn.parameters?.properties || {};
        const required = fn.parameters?.required || [];
        const paramsArray = Object.entries(props).map(([k, v], j) => ({
          id: "param-" + i + "-" + j,
          name: k,
          type: v.type || "?",
          description: v.description || "",
          required: required.includes(k)
        }));
        return {
          id: "tool-" + i,
          name: fn.name || "?",
          description: fn.description || "",
          paramsArray
        };
      });
    } catch {
      return [];
    }
  }

  _extractToolInvocationsFromOutput(outputPayload) {
    if (!outputPayload) return [];
    const decoded = this._decodeTraceText(outputPayload);
    try {
      const parsed = JSON.parse(decoded);
      const invocations = Array.isArray(parsed?.toolInvocations)
        ? parsed.toolInvocations
        : [];
      return invocations.map((ti, i) => ({
        id: "invocation-" + i,
        functionName: ti.function?.name || "?",
        arguments: ti.function?.arguments || ""
      }));
    } catch {
      return [];
    }
  }

  _extractLlmResponse(outputPayload) {
    if (!outputPayload) return "";
    const decoded = this._decodeTraceText(outputPayload);
    try {
      const parsed = JSON.parse(decoded);
      return parsed?.llmResponse || "";
    } catch {
      return "";
    }
  }

  _extractActionResponse(outputPayload) {
    if (!outputPayload) return null;
    const decoded = this._decodeTraceText(outputPayload);
    try {
      const parsed = JSON.parse(decoded);
      return parsed?.actionResponse || null;
    } catch {
      return null;
    }
  }

  _extractErrorMessage(rawError) {
    if (!rawError || rawError === "NOT_SET") return "";
    const decoded = this._decodeTraceText(rawError);
    try {
      const obj = JSON.parse(decoded);
      if (obj.errors?.[0]?.errorDetails?.message)
        return obj.errors[0].errorDetails.message;
      if (obj.errorMessage) return obj.errorMessage;
      if (obj.message) return obj.message;
      if (obj.error) return obj.error;
      if (obj.plannerMessageType) return obj.plannerMessageType;
      return decoded;
    } catch {
      return decoded;
    }
  }

  async _copyToClipboard(text) {
    if (!text) return;
    try {
      await navigator.clipboard.writeText(text);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Copied",
          message: "Copied to clipboard",
          variant: "success"
        })
      );
    } catch {
      /* clipboard not available */
    }
  }

  handleCopyClick(event) {
    const text = event.currentTarget?.dataset?.copy;
    this._copyToClipboard(text);
  }

  handleToggleSection(event) {
    const sectionEl = event.currentTarget?.closest(".debug-section");
    if (sectionEl) {
      sectionEl.classList.toggle("collapsed");
    }
  }

  _matchesFilters(eventRow, filters) {
    if (!filters || typeof filters !== "object") {
      return true;
    }

    const search = String(filters.search || "")
      .trim()
      .toLowerCase();
    if (search) {
      const haystack = [
        eventRow?.observationType,
        eventRow?.integrationCode,
        eventRow?.correlationId,
        eventRow?.reasoningStepName,
        eventRow?.topicName
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      if (!haystack.includes(search)) {
        return false;
      }
    }

    if (filters.correlationId) {
      const normalized = String(filters.correlationId).trim().toLowerCase();
      if (String(eventRow?.correlationId || "").toLowerCase() !== normalized) {
        return false;
      }
    }

    if (filters.observationType) {
      const normalized = String(filters.observationType).trim().toLowerCase();
      if (
        String(eventRow?.observationType || "").toLowerCase() !== normalized
      ) {
        return false;
      }
    }

    if (filters.integrationCode) {
      const normalized = String(filters.integrationCode).trim().toLowerCase();
      if (
        !String(eventRow?.integrationCode || "")
          .toLowerCase()
          .includes(normalized)
      ) {
        return false;
      }
    }

    const eventDate = Date.parse(eventRow?.occurredAtRaw || "");
    if (!Number.isNaN(eventDate)) {
      if (filters.fromOccurredAt) {
        const fromDate = Date.parse(filters.fromOccurredAt);
        if (!Number.isNaN(fromDate) && eventDate < fromDate) {
          return false;
        }
      }
      if (filters.toOccurredAt) {
        const toDate = Date.parse(filters.toOccurredAt);
        if (!Number.isNaN(toDate) && eventDate > toDate) {
          return false;
        }
      }
    }

    return true;
  }

  handleRefreshClick() {
    this._fetchData();
  }

  handleLiveSessionIdChange(event) {
    this.liveSessionId = event.target.value;
    this.isLiveQueryDisabled =
      !this.liveSessionId || this.liveSessionId.trim().length === 0;
  }

  handleRecentSessionSelect(event) {
    this.liveSessionId = event.detail.value;
    this.isLiveQueryDisabled = false;
  }

  async handleLiveQueryClick() {
    if (this.isLiveQueryDisabled) return;

    this.isLoading = true;
    this.hasError = false;
    this.errorMessage = "";

    try {
      const resultStr = await getLiveSessionTrace({
        sessionId: this.liveSessionId.trim()
      });
      if (!resultStr) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Info",
            message: "No live session data found for this ID.",
            variant: "info"
          })
        );
        this.isLoading = false;
        return;
      }

      const parsed = JSON.parse(resultStr);

      // DEBUG: log raw structure from live query
      console.log("[LiveQuery] keys:", Object.keys(parsed));
      console.log(
        "[LiveQuery] session:",
        !!parsed.session,
        "conversation:",
        !!parsed.conversation,
        "trace:",
        !!parsed.trace
      );
      if (parsed.trace) {
        console.log(
          "[LiveQuery] trace.steps:",
          parsed.trace?.steps?.length ?? "missing"
        );
        console.log(
          "[LiveQuery] trace.tokenData:",
          Object.keys(parsed.trace?.tokenData || {}).length,
          "entries"
        );
        console.log(
          "[LiveQuery] trace.interactions:",
          parsed.trace?.interactions?.length ?? "missing"
        );
      }
      if (parsed.conversation) {
        console.log(
          "[LiveQuery] conversation.entries:",
          parsed.conversation?.entries?.length ?? "missing"
        );
      }

      this._contextData = JSON.stringify({
        pluginName: "Agentforce_Core_Card",
        filters: this.parsedContext?.filters || {},
        location: "dashboard",
        refreshToken: Date.now().toString(),
        agentforcePayload: parsed
      });
      this.parsedContext = JSON.parse(this._contextData);

      await this._fetchData();

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Live session data loaded successfully.",
          variant: "success"
        })
      );
    } catch (e) {
      this.hasError = true;
      this.errorMessage =
        e.message || "An error occurred fetching live session data.";
      this.sessionRows = [];
      this.totalSessions = 0;
      this.totalEvents = 0;
      this.totalErrors = 0;
      this.totalWarnings = 0;
      this.totalUncorrelatedEvents = 0;
    } finally {
      this.isLoading = false;
    }
  }

  handleLoadTestClick() {
    const input = this.template.querySelector("input[data-test-payload-input]");
    if (input) {
      input.click();
    }
  }

  async handleTestPayloadSelected(event) {
    const file =
      event.target.files && event.target.files.length > 0
        ? event.target.files[0]
        : null;
    event.target.value = "";

    if (!file) {
      return;
    }

    this.isLoading = true;
    this.hasError = false;
    this.errorMessage = "";

    try {
      const fileText = await file.text();
      const payload = JSON.parse(fileText);
      this._contextData = JSON.stringify({
        pluginName: "Agentforce_Core_Card",
        filters: this.parsedContext?.filters || {},
        location: "dashboard",
        refreshToken: Date.now().toString(),
        agentforcePayload: payload
      });
      this.parsedContext = JSON.parse(this._contextData);
      await this._fetchData();
    } catch (error) {
      const message =
        error instanceof SyntaxError ? "Invalid JSON file" : error?.message;
      this.hasError = true;
      this.errorMessage = message || "Unable to load test JSON file";
      this.sessionRows = [];
      this.totalSessions = 0;
      this.totalEvents = 0;
      this.totalErrors = 0;
      this.totalWarnings = 0;
      this.totalUncorrelatedEvents = 0;
    } finally {
      this.isLoading = false;
    }
  }

  handleToggleQueryInspector() {
    this.showQueryInspector = !this.showQueryInspector;
  }

  async handleSessionSelect(event) {
    const correlationId = event.currentTarget?.dataset?.correlation;
    if (!correlationId) {
      return;
    }
    this.selectedSessionKey = correlationId;
    const session = this.selectedSession;
    const firstEvent =
      session && session.events.length > 0 ? session.events[0] : null;
    this.selectedEventId = firstEvent ? firstEvent.id : "";
    if (this.selectedEventId) {
      await this._loadEventDetail(this.selectedEventId);
    } else {
      this.selectedEventDetail = null;
    }
  }

  async handleEventSelect(event) {
    const eventId = event.currentTarget?.dataset?.eventId;
    if (!eventId) {
      return;
    }
    this.selectedEventId = eventId;
    await this._loadEventDetail(eventId);
  }

  get selectedSessionCountLabel() {
    return `${this.totalSessions} sessions`;
  }

  get uncorrelatedLabel() {
    return `${this.totalUncorrelatedEvents} uncorrelated events`;
  }

  handleSessionClick(event) {
    if (this.dataMode === "session-payload") {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Not Available",
          message: "No persisted logs exist for session-payload mode.",
          variant: "info"
        })
      );
      return;
    }

    const correlationId =
      this.selectedSessionKey || event.currentTarget?.dataset?.correlation;
    if (
      !correlationId ||
      correlationId === NO_CORRELATION_KEY ||
      !this.messageContext
    ) {
      return;
    }

    publish(this.messageContext, IEF_PLUGIN_ACTIONS, {
      pluginName: "Agentforce_Core_Card",
      action: "navigate_to_filters",
      payload: {
        correlationId
      }
    });
  }
}
