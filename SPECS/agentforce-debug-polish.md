# Spec: Agentforce Plugin Debug Data Polish

## Context

The `ief-plugin-agentforce-core` plugin displays Agentforce session data in Salesforce. It works for loading sessions and showing conversation entries, but is **missing the debugging data** that the Chrome extension ("Agentforce Extension Debugger") provides.

**Goal:** Make the plugin show the same debugging data as the extension — LLM prompts, tool definitions, token metrics, gateway IDs, tool invocations — so developers can debug agent sessions without leaving Salesforce.

**NOT needed:** Chat bubble visualization (already exists natively in Salesforce). This spec is about **debug data only**.

---

## Current State

### What Works ✅

- Session list loads from Data Cloud (persisted mode)
- Live Query fetches session by ID
- Conversation entries (BOT_MESSAGE, USER_MESSAGE) display in timeline
- Detail panel shows basic fields (Agent, Model, Step Type, etc.)
- Payload sections (Raw Input, Raw Output) show prettified JSON
- Session JSON file loading works

### What's Broken/Buggy ⚠️

1. **Live Query returns trace data but `_summarizeSessionPayload` doesn't process it correctly** — trace steps show as "No LLM, action, or guardrail steps" even though the Chrome extension shows 6+ steps for the same session
2. **`visibleEvents` empty after live query** despite "Success" toast — the `_extractSessionPayload` path finds the payload but `_summarizeSessionPayload` returns no trace events

### What's Missing ❌

1. **Trace steps not showing** — the biggest blocker (see Bugs above)
2. **Token data not linked to steps** — `tokenData` map keyed by gateway request ID exists in trace but isn't matched to steps for per-step token display
3. **Pre/Post step variables** — stored on step objects but not extracted
4. **Error messages** — step-level errors (`ssot__ErrorMessageText__c`) not surfaced

---

## Architecture

### Data Flow

```
User clicks "Live Query"
  → getLiveSessionTrace({ sessionId })  [Apex call]
  → JSON string returned
  → parsed = JSON.parse(resultStr)
  → stored as parsedContext.agentforcePayload
  → _extractSessionPayload(parsedContext) extracts { session, conversation, trace }
  → _summarizeSessionPayload(payload, filters) builds events array
  → events → visibleEvents (filtered) → rendered
```

### Key Data Structures

**Live query response** (from `pretty_session.json`):

```json
{
  "session": { "Id": "...", "Name": "MS-00000466", ... },
  "conversation": {
    "uuid": "...",
    "entries": [
      { "role": "bot", "type": "BOT_MESSAGE", "message": "...", "timestamp": "..." },
      { "role": "user", "type": "USER_MESSAGE", "message": "...", "timestamp": "..." }
    ]
  },
  "trace": {
    "dcSessionId": "019aa357-...",
    "steps": [
      {
        "ssot__Name__c": "AiCopilot_ReactTopicPrompt",
        "ssot__ReasoningStepType__c": "LLM_STEP",
        "ssot__InputValueText__c": "{\"messages\":[{\"role\":\"system\",\"content\":\"...\"},...],\"tools\":[...]}",
        "ssot__OutputValueText__c": "{\"llmResponse\":\"...\",\"toolInvocations\":[...]}",
        "ssot__GenAiGatewayRequestId__c": "5622fea8-...",
        "ssot__ModelName__c": "gpt-4o",
        "ssot__StepStartTime__c": "2025-11-20T19:17:45.602Z",
        "ssot__StepEndTime__c": "2025-11-20T19:17:45.972Z",
        "ssot__ErrorMessageText__c": null,
        "ssot__PreStepVariableText__c": "{\"variables\":[...]}",
        "ssot__PostStepVariableText__c": "{\"variables\":[...]}",
        "ssot__AttributeText__c": "{\"internalTraceId\":\"...\"}"
      },
      ...
    ],
    "tokenData": {
      "5622fea8-...": {
        "gatewayRequestId": "5622fea8-...",
        "model": "OpenAI-gpt-4o-2024-11-20",
        "provider": "azureOpenAI",
        "promptTokens": 835,
        "completionTokens": 0,
        "totalTokens": 835,
        "temperature": 0,
        "prompt": "...full prompt string with \\n escapes..."
      },
      ...
    },
    "interactions": [...]
  }
}
```

### Key Files

| File                             | Purpose                                   |
| -------------------------------- | ----------------------------------------- |
| `iefAgentforceCoreCardImpl.js`   | Main component logic (1932 lines)         |
| `iefAgentforceCoreCardImpl.html` | Template (777 lines, recently redesigned) |
| `iefAgentforceCoreCardImpl.css`  | Styles (~400 lines, recently enhanced)    |

---

## Phase 1: Fix Trace Step Visibility (CRITICAL)

**Problem:** Live query returns trace data but `_summarizeSessionPayload` doesn't produce trace step events.

**Root Cause Investigation:**

1. In `handleLiveQueryClick` (line 1756), the raw parsed result is wrapped:
   ```js
   this._contextData = JSON.stringify({
     agentforcePayload: parsed
   });
   ```
2. `_extractSessionPayload` checks for `parsedContext.agentforcePayload.session/conversation/trace`
3. If found, returns the payload to `_fetchData` which calls `_summarizeSessionPayload`
4. Inside `_summarizeSessionPayload` (line 708+):
   - Extracts `trace.steps` from `payload.trace`
   - For each step, creates an event object
   - **BUG LIKELY HERE:** Check if `trace.steps` exists and has data

**Debug logging added** at line 1779-1798 shows:

- `[LiveQuery] keys:` — what keys the raw response has
- `[LiveQuery] session: true/false conversation: true/false trace: true/false`
- `[LiveQuery] trace.steps: N` — count of steps
- `[LiveQuery] trace.tokenData: N entries`
- `[LiveQuery] conversation.entries: N`

**To investigate:**

- Check browser console after live query
- If `trace.steps` is missing or empty → the Apex method `getLiveSessionTrace` isn't returning trace data → need to check the Apex implementation
- If `trace.steps` has data but no events produced → bug in `_summarizeSessionPayload` event creation logic (lines 710-900)

**Files to check:**

- `iefAgentforceCoreCardImpl.js` lines 1756-1812 (handleLiveQueryClick)
- `iefAgentforceCoreCardImpl.js` lines 708-900 (\_summarizeSessionPayload)
- The Apex class that implements `getLiveSessionTrace` (find in project)

---

## Phase 2: Per-Step Token Linking

Once trace steps display, link token data from `trace.tokenData` to each step event.

**Current state:** Events have `gatewayRequestId` and `stepTokenInfo` populated in `_summarizeSessionPayload` (lines 810-876), and getters exist (`detailStepTokenInfo`, `detailStepPromptTokens`, etc.), but need to verify they work.

**What to verify:**

1. Each event has `gatewayRequestId` from `step.ssot__GenAiGatewayRequestId__c`
2. Each event has `stepTokenInfo` looked up from `tokenData[gatewayRequestId]`
3. Detail panel shows Token Metrics section when `detailHasTokenInfo` is true
4. Token counts (prompt/completion/total) display correctly

**If token data is missing from live query:**

- Check if `getLiveSessionTrace` Apex method returns `tokenData` map
- May need to query a separate Data Cloud object for token metrics

---

## Phase 3: Full LLM Prompt Display

**Status:** UI is built, need to verify data flow.

**What exists:**

- `detailStepPromptFull` getter decodes `stepTokenInfo.prompt` with escape sequences
- HTML shows "Full LLM Prompt" section with copy button
- Token data comes from `tokenData[gatewayRequestId].prompt`

**To verify:**

- When you click an LLM step with token data, does the Full LLM Prompt section appear?
- Does it show readable text (not raw escape sequences)?
- Copy button works?

---

## Phase 4: Messages & Tools Parsing

**Status:** UI is built, need to verify data flow.

**What exists:**

- `detailParsedMessages` getter parses `ssot__InputValueText__c` → extracts `messages[]`
- `_extractMessagesFromInput` adds `roleClass` for role badges
- HTML shows Messages section with role badges (system/user/assistant/tool)
- `detailParsedTools` getter parses tools from input, creates `paramsArray`
- HTML shows Tools section with parameter tables

**To verify:**

- LLM steps show Messages section with color-coded role badges
- Tools section shows tool names and parameter tables
- Raw content is readable (not HTML-encoded)

---

## Phase 5: Tool Invocations & LLM Response

**Status:** UI is built, need to verify data flow.

**What exists:**

- `detailParsedToolInvocations` extracts `toolInvocations[]` from output
- HTML shows Tool Calls section with function name and arguments
- `detailParsedLlmResponse` extracts `llmResponse` from output

**To verify:**

- After an LLM step that called tools, Tool Calls section shows the function name and JSON arguments
- LLM Response section shows the model's text response

---

## Phase 6: Action Steps (Secondary)

**Status:** UI is built, need to verify data flow for ACTION_STEP type events.

**What exists:**

- `detailParsedActionInput` extracts `actionInput` key-value pairs
- `detailParsedActionResponse` extracts `actionResponse`
- `detailActionName` cleans up the action name

---

## Phase 7: Error Extraction

**Status:** UI is built, need to verify.

**What exists:**

- `detailErrorText` getter reads `event.errorText`
- `errorText` is populated in `_summarizeSessionPayload` from `step.ssot__ErrorMessageText__c`
- Error section has distinct red styling

**To verify:**

- Steps with errors show red error banner
- Error message is clean (not raw JSON)

---

## Phase 8: Trace IDs & Pre/Post Variables

**Status:** UI is built (collapsed by default), need to verify.

**What exists:**

- `detailGatewayRequestId`, `detailGenerationId`, etc. getters
- `detailPreStepVars`, `detailPostStepVars` getters
- Trace IDs section with copyable IDs
- Pre/Post Step Variables sections

---

## Known Bugs to Fix

### Bug 1: Live Query trace steps not visible

**Severity:** CRITICAL — blocks all debugging functionality
**Symptoms:** Session loads, conversation entries show, but "No LLM, action, or guardrail steps"
**Debug:** Browser console `[LiveQuery]` logs show what data was returned
**Fix location:** Either Apex method or `_summarizeSessionPayload`

### Bug 2: Toast fires even when no data displayed

**Severity:** LOW — misleading UX
**Fix:** Move toast inside the block that confirms events were produced:

```js
await this._fetchData();
// Only show success if we actually got events
if (this.totalEvents > 0) {
  this.dispatchEvent(new ShowToastEvent({ ... }));
}
```

---

## Testing Checklist

After each phase, test with:

1. **Live Query** using session ID `019aa357-e388-7484-a6b3-c2a864752c7c`
2. **Load Debug JSON** using `pretty_session.json`

| #   | Test                       | Expected Result                                  |
| --- | -------------------------- | ------------------------------------------------ |
| 1   | Live Query loads session   | Session shows in list, events count > 0          |
| 2   | Click an LLM step          | Reasoning Steps shows LLM_STEP entries           |
| 3   | Click LLM step → Detail    | Token Metrics section visible with model, tokens |
| 4   | Click LLM step → Detail    | Messages section shows role-colored messages     |
| 5   | Click LLM step → Detail    | Tools section shows parameter tables             |
| 6   | Click LLM step → Detail    | LLM Response section shows text                  |
| 7   | Click LLM step → Detail    | Tool Calls section (if tools were invoked)       |
| 8   | Click Action step → Detail | Action name, input params, response              |
| 9   | Click any step → Detail    | Trace IDs section shows copyable IDs             |
| 10  | Click Copy button          | Toast "Copied to clipboard"                      |
| 11  | Expand/collapse sections   | Chevrons rotate, content shows/hides             |

---

## Model Assignment

| Phase             | Model  | Why                                       |
| ----------------- | ------ | ----------------------------------------- |
| This spec         | opus   | Architectural analysis                    |
| Bug investigation | sonnet | Code tracing, log analysis                |
| Phase 1 fix       | sonnet | Targeted fix                              |
| Phases 2-8        | sonnet | Mostly verification, minimal code changes |
| Deploy & test     | sonnet | Deployment, validation                    |

---

## Implementation Order

1. **Investigate live query** — check console logs, determine if trace data is returned
2. **Fix trace step visibility** — this is the gate for everything else
3. **Verify per-step tokens** — once steps show, verify token linking works
4. **Verify rich detail panels** — messages, tools, outputs
5. **Fix toast logic** — move success toast to only fire when events exist
6. **Clean up debug logs** — remove console.log statements before final deploy
7. **Full test** — run through testing checklist

---

## Reference: Chrome Extension Rendering

The extension (`render.js` line 252+) renders each step with:

```
[Avatar L|A|G] AiCopilot_ReactTopicPrompt [835 tk] 370ms
  ▶ Prompt: AiCopilot_ReactTopicPrompt · Plan: ff1f1d4f-... · Step: 352793072820063
  ▶ INPUT — AICOPILOT_REACTTOPICPROMPT (4,137 CHARS)
    [Role-based message blocks with collapsible content]
    [Tool definitions with parameter trees]
  ▶ OUTPUT
    Car_Buying_Assistant0 (the LLM response text)
    [Gateway metrics: model, prompt tokens, completion tokens, temperature]
    [Gateway IDs: Gen, GW Req, GW Resp]
    [Tool invocations with formatted JSON arguments]
```

The plugin should show equivalent data in the detail panel when clicking a step. No need to match the exact UI layout — just expose the same information.
