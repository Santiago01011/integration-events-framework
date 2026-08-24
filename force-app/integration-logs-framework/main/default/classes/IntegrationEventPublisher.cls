/**
 * @description Public utility for publishing IntegrationEvent__e used by
 * the Integration Events Framework. Centralizes event publishing with bulk support,
 * safe field truncation, and Custom Metadata kill switches (Zero SOQL).
 */
public without sharing class IntegrationEventPublisher {
  // Cache of disabled integration codes (loaded once per transaction)
  private static Set<String> disabledCodes;

  /**
   * @description Loads the set of disabled integration codes from Custom Metadata using getAll() (Zero SOQL).
   */
  private static void loadDisabledCodes() {
    if (disabledCodes == null) {
      disabledCodes = new Set<String>();
      Map<String, idhIntegration_Definition__mdt> allDefs = idhIntegration_Definition__mdt.getAll();
      if (allDefs != null) {
        for (idhIntegration_Definition__mdt def : allDefs.values()) {
          if (
            def.Enabled__c == false && String.isNotBlank(def.IntegrationCode__c)
          ) {
            disabledCodes.add(def.IntegrationCode__c.toUpperCase());
          }
        }
      }
    }
  }

  /**
   * @description Checks if an integration code is disabled (kill switch active).
   * @param integrationCode The code to check.
   * @return true if the code is explicitly disabled, false otherwise.
   */
  private static Boolean isDisabled(String integrationCode) {
    loadDisabledCodes();
    return String.isNotBlank(integrationCode) &&
      disabledCodes.contains(integrationCode.toUpperCase());
  }

  /**
   * @description Allows tests to inject disabled codes without querying metadata.
   * @param testCodes Set of integration codes to treat as disabled.
   */
  @TestVisible
  private static void setTestDisabledCodes(Set<String> testCodes) {
    disabledCodes = new Set<String>();
    if (testCodes != null) {
      for (String code : testCodes) {
        disabledCodes.add(code.toUpperCase());
      }
    }
  }

  /**
   * @description Bulk emitter: publishes a list of event requests in a single EventBus transaction.
   * @param requests List of IEF_EventRequest objects to publish.
   */
  public static void emit(List<IEF_EventRequest> requests) {
    if (requests == null || requests.isEmpty()) {
      return;
    }

    // Safety guard: prevent framework from crashing transaction if DML limit is near capacity
    if (Limits.getDMLStatements() >= Limits.getLimitDMLStatements() - 1) {
      System.debug(
        LoggingLevel.ERROR,
        'IEF FRAMEWORK: DML Limit near capacity. Bulk events dropped: ' +
        requests.size()
      );
      return;
    }

    List<IntegrationEvent__e> eventsToPublish = new List<IntegrationEvent__e>();

    for (IEF_EventRequest req : requests) {
      if (req == null || isDisabled(req.integrationCode)) {
        continue;
      }
      eventsToPublish.add(
        new IntegrationEvent__e(
          IntegrationCode__c = req.integrationCode?.left(100),
          ObservationType__c = req.observationType?.left(100),
          CorrelationId__c = req.correlationId?.left(80),
          ParentEventId__c = req.parentEventId?.left(80),
          Context__c = req.context?.left(32768),
          OccurredAt__c = req.occurredAt != null
            ? req.occurredAt
            : Datetime.now()
        )
      );
    }

    if (eventsToPublish.isEmpty()) {
      return;
    }

    List<Database.SaveResult> results = EventBus.publish(eventsToPublish);
    List<String> failedMessages = new List<String>();

    for (Database.SaveResult result : results) {
      if (!result.isSuccess()) {
        for (Database.Error err : result.getErrors()) {
          failedMessages.add(err.getStatusCode() + ': ' + err.getMessage());
        }
      }
    }

    if (!failedMessages.isEmpty()) {
      throw new IEF_PublishException(
        'Failed to publish ' +
          failedMessages.size() +
          ' event(s): ' +
          String.join(failedMessages, '; ')
      );
    }
  }

  /**
   * @description Canonical emitter: publishes a single neutral observation with correlation.
   * @param integrationCode Integration identifier from metadata.
   * @param observationType Fact-based observation type.
   * @param correlationId Correlation identifier to propagate.
   * @param parentEventId Optional parent event identifier.
   * @param contextMap Opaque context payload as a Map (will be serialized to JSON).
   */
  public static void emit(
    String integrationCode,
    String observationType,
    String correlationId,
    String parentEventId,
    Map<String, Object> contextMap
  ) {
    emit(
      new List<IEF_EventRequest>{
        new IEF_EventRequest(
          integrationCode,
          observationType,
          correlationId,
          parentEventId,
          contextMap
        )
      }
    );
  }

  /**
   * @description Canonical emitter: publishes a single neutral observation with correlation.
   * @param integrationCode Integration identifier from metadata.
   * @param observationType Fact-based observation type.
   * @param correlationId Correlation identifier to propagate.
   * @param parentEventId Optional parent event identifier.
   * @param context Opaque context payload (JSON or string).
   */
  public static void emit(
    String integrationCode,
    String observationType,
    String correlationId,
    String parentEventId,
    String context
  ) {
    emit(
      new List<IEF_EventRequest>{
        new IEF_EventRequest(
          integrationCode,
          observationType,
          correlationId,
          parentEventId,
          context
        )
      }
    );
  }

  /**
   * @description Standardized error handling for UI controllers.
   * Logs the exception to the framework and throws an AuraHandledException.
   * @param e Exception to log and re-throw.
   */
  public static void handleControllerError(Exception e) {
    emit(
      'FRAMEWORK_INTERNAL',
      'INTERNAL_CONTROLLER_ERROR',
      null,
      null,
      e.getMessage() + '\n' + e.getStackTraceString()
    );
    AuraHandledException auraEx = new AuraHandledException(e.getMessage());
    auraEx.setMessage(e.getMessage());
    throw auraEx;
  }

  /**
   * @description Standardized error handling for UI controllers.
   * Logs the exception to the framework and throws an AuraHandledException.
   * @param message Message to log and re-throw.
   */
  public static void handleControllerError(String message) {
    emit(
      'FRAMEWORK_INTERNAL',
      'INTERNAL_CONTROLLER_ERROR',
      null,
      null,
      message
    );
    AuraHandledException auraEx = new AuraHandledException(message);
    auraEx.setMessage(message);
    throw auraEx;
  }
}
