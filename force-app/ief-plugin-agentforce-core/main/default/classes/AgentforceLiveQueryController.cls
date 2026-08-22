/**
 * @description Controller for fetching live Agentforce sessions natively via SOQL.
 *
 * Bridges MessagingSession -> Data Cloud agent trace data. The Chrome Agentforce
 * Debugger extension uses the DC Query API; this controller uses SOQL against the
 * standard DLMs so no extension install is required.
 *
 * Input sessionId accepts any of:
 *  - MessagingSession.Id (e.g. 0MwKZ000000E6bn0AC)
 *  - MessagingSession.Name (e.g. MS-00000466)
 *  - Data Cloud agent session UUID (e.g. 019aa357-e388-7484-a6b3-c2a864752c7c)
 *
 * Since ssot__AiAgentInteractionStep__dlm has no direct session field, the step
 * query filters by interactionId collected from ssot__AiAgentInteraction__dlm.
 */
public with sharing class AgentforceLiveQueryController {
  private static final String STEP_DLM = 'ssot__AiAgentInteractionStep__dlm';
  private static final String INTERACTION_DLM = 'ssot__AiAgentInteraction__dlm';
  private static final String SESSION_DLM = 'ssot__AiAgentSession__dlm';

  @AuraEnabled
  public static String getLiveSessionTrace(String sessionId) {
    if (String.isBlank(sessionId)) {
      return null;
    }

    String input = sessionId.trim();

    Map<String, Object> payload = new Map<String, Object>();
    Map<String, Object> sessionData = new Map<String, Object>();
    Map<String, Object> conversationData = new Map<String, Object>();
    Map<String, Object> traceData = new Map<String, Object>();
    Map<String, Object> errors = new Map<String, Object>();

    traceData.put('dcSessionId', input);

    // 1. Resolve MessagingSession (if input is an MS Id or Name) and its time window.
    MessagingSession ms = resolveMessagingSession(input, errors);
    Datetime windowStart = null;
    Datetime windowEnd = null;

    if (ms != null) {
      sessionData.put('Id', ms.Id);
      sessionData.put('Name', ms.Name);
      sessionData.put('Status', ms.Status);
      sessionData.put('StartTime', ms.StartTime);
      sessionData.put('EndTime', ms.EndTime);
      sessionData.put('ConversationId', ms.ConversationId);

      windowStart = ms.StartTime;
      windowEnd = ms.EndTime == null ? Datetime.now() : ms.EndTime;

      // Fetch conversation entries for the chat transcript.
      if (String.isNotBlank(ms.ConversationId)) {
        conversationData = fetchConversationEntries(ms.ConversationId, errors);
      }
    }

    // 2. Resolve DC session UUID(s) and collect interaction rows/ids.
    //    - If input looks like a UUID: filter interactions directly by ssot__AiAgentSessionId__c.
    //    - Otherwise (MS resolved): filter interactions by the MS time window.
    List<SObject> interactions = new List<SObject>();
    Set<String> interactionIds = new Set<String>();
    Set<String> dcSessionUuids = new Set<String>();

    Boolean inputLooksLikeUuid = isUuid(input);

    try {
      if (inputLooksLikeUuid) {
        String q =
          'SELECT ssot__Id__c, ssot__AiAgentSessionId__c, ssot__StartTimestamp__c, ' +
          'ssot__EndTimestamp__c, ssot__TopicApiName__c, ssot__AiAgentInteractionType__c ' +
          'FROM ' +
          INTERACTION_DLM +
          ' ' +
          'WHERE ssot__AiAgentSessionId__c = :input ' +
          'ORDER BY ssot__StartTimestamp__c ASC LIMIT 500';
        interactions = Database.query(q);
      } else if (windowStart != null) {
        String q =
          'SELECT ssot__Id__c, ssot__AiAgentSessionId__c, ssot__StartTimestamp__c, ' +
          'ssot__EndTimestamp__c, ssot__TopicApiName__c, ssot__AiAgentInteractionType__c ' +
          'FROM ' +
          INTERACTION_DLM +
          ' ' +
          'WHERE ssot__StartTimestamp__c >= :windowStart ' +
          'AND ssot__StartTimestamp__c <= :windowEnd ' +
          'ORDER BY ssot__StartTimestamp__c ASC LIMIT 500';
        interactions = Database.query(q);
      }

      for (SObject i : interactions) {
        String iid = (String) i.get('ssot__Id__c');
        if (String.isNotBlank(iid))
          interactionIds.add(iid);
        String sid = (String) i.get('ssot__AiAgentSessionId__c');
        if (String.isNotBlank(sid))
          dcSessionUuids.add(sid);
      }
      traceData.put('interactions', interactions);
    } catch (Exception e) {
      errors.put('interactions', e.getMessage());
    }

    // Update dcSessionId to the resolved DC UUID when we found exactly one.
    if (!dcSessionUuids.isEmpty()) {
      if (dcSessionUuids.size() == 1) {
        traceData.put('dcSessionId', new List<String>(dcSessionUuids)[0]);
      }
      traceData.put('dcSessionUuids', new List<String>(dcSessionUuids));
    }

    // 3. Fetch steps for the collected interactions.
    List<SObject> steps = new List<SObject>();
    if (!interactionIds.isEmpty()) {
      try {
        String q =
          'SELECT ssot__Id__c, ssot__Name__c, ssot__AiAgentInteractionStepType__c, ' +
          'ssot__InputValueText__c, ssot__OutputValueText__c, ssot__ErrorMessageText__c, ' +
          'ssot__StartTimestamp__c, ssot__EndTimestamp__c, ' +
          'ssot__GenerationId__c, ssot__GenAiGatewayRequestId__c, ssot__GenAiGatewayResponseId__c, ' +
          'ssot__AiAgentInteractionId__c, ssot__AttributeText__c ' +
          'FROM ' +
          STEP_DLM +
          ' ' +
          'WHERE ssot__AiAgentInteractionId__c IN :interactionIds ' +
          'ORDER BY ssot__StartTimestamp__c ASC LIMIT 2000';
        steps = Database.query(q);
      } catch (Exception e) {
        errors.put('steps', e.getMessage());
      }
    }
    traceData.put('steps', steps);

    // 4. Optional session enrichment (timestamps from DC session DLM).
    if (!dcSessionUuids.isEmpty()) {
      try {
        List<String> uuidList = new List<String>(dcSessionUuids);
        String q =
          'SELECT ssot__Id__c, ssot__StartTimestamp__c, ssot__EndTimestamp__c ' +
          'FROM ' +
          SESSION_DLM +
          ' ' +
          'WHERE ssot__Id__c IN :uuidList LIMIT 50';
        traceData.put('dcSessions', Database.query(q));
      } catch (Exception e) {
        errors.put('dcSessions', e.getMessage());
      }
    }

    if (!errors.isEmpty()) {
      traceData.put('errors', errors);
    }
    traceData.put('available', !steps.isEmpty() || !interactions.isEmpty());

    payload.put('session', sessionData);
    payload.put('conversation', conversationData);
    payload.put('trace', traceData);

    return JSON.serialize(payload);
  }

  @AuraEnabled(cacheable=true)
  public static List<Map<String, String>> getRecentSessionIds() {
    List<Map<String, String>> results = new List<Map<String, String>>();
    Set<String> seen = new Set<String>();

    try {
      List<MessagingSession> sessions = [
        SELECT Id, Name
        FROM MessagingSession
        ORDER BY StartTime DESC
        LIMIT 10
      ];
      for (MessagingSession s : sessions) {
        if (seen.add(s.Id)) {
          Map<String, String> item = new Map<String, String>();
          item.put('label', s.Name);
          item.put('value', s.Id);
          results.add(item);
        }
      }
    } catch (Exception e) {
      System.debug(
        'Error fetching recent MessagingSessions: ' + e.getMessage()
      );
    }

    if (results.isEmpty()) {
      // Fallback: recent DC agent sessions.
      try {
        String q =
          'SELECT ssot__Id__c FROM ' +
          SESSION_DLM +
          ' ORDER BY ssot__StartTimestamp__c DESC LIMIT 10';
        List<SObject> dcSessions = Database.query(q);
        for (SObject s : dcSessions) {
          String id = (String) s.get('ssot__Id__c');
          if (String.isNotBlank(id) && seen.add(id)) {
            Map<String, String> item = new Map<String, String>();
            item.put('label', id);
            item.put('value', id);
            results.add(item);
          }
        }
      } catch (Exception e) {
        System.debug('Error fetching DC sessions: ' + e.getMessage());
      }
    }

    return results;
  }

  private static MessagingSession resolveMessagingSession(
    String input,
    Map<String, Object> errors
  ) {
    if (!isObjectQueryable('MessagingSession'))
      return null;
    try {
      List<MessagingSession> sessions = [
        SELECT Id, Name, Status, StartTime, EndTime, ConversationId
        FROM MessagingSession
        WHERE Id = :input OR Name = :input
        LIMIT 1
      ];
      return sessions.isEmpty() ? null : sessions[0];
    } catch (Exception e) {
      errors.put('messagingSession', e.getMessage());
      return null;
    }
  }

  private static Map<String, Object> fetchConversationEntries(
    String convId,
    Map<String, Object> errors
  ) {
    Map<String, Object> result = new Map<String, Object>();
    result.put('uuid', convId);
    result.put('entries', new List<Map<String, Object>>());

    if (!isObjectQueryable('ConversationEntry'))
      return result;

    try {
      String q =
        'SELECT Id, ActorName, ActorType, Message, EntryTime ' +
        'FROM ConversationEntry WHERE ConversationId = :convId ' +
        'ORDER BY EntryTime ASC';
      List<SObject> entries = Database.query(q);
      List<Map<String, Object>> mapped = new List<Map<String, Object>>();
      for (SObject e : entries) {
        Map<String, Object> m = new Map<String, Object>();
        m.put('identifier', e.get('Id'));
        m.put('messageText', e.get('Message'));
        Datetime t = (Datetime) e.get('EntryTime');
        if (t != null)
          m.put('serverReceivedTimestamp', t.getTime());

        Map<String, Object> sender = new Map<String, Object>();
        String actorType = (String) e.get('ActorType');
        sender.put('role', actorType);
        if (actorType == 'Bot')
          sender.put('appType', 'chatbot');
        else if (actorType == 'System')
          sender.put('appType', 'conversation');
        else
          sender.put('appType', 'live_message');
        m.put('sender', sender);

        mapped.add(m);
      }
      result.put('entries', mapped);
    } catch (Exception e) {
      errors.put('conversationEntries', e.getMessage());
    }
    return result;
  }

  private static Boolean isUuid(String s) {
    if (String.isBlank(s))
      return false;
    // 8-4-4-4-12 hex pattern, case-insensitive.
    return Pattern.matches(
      '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
      s
    );
  }

  private static Boolean isObjectQueryable(String objectName) {
    return Schema.getGlobalDescribe().containsKey(objectName);
  }
}
