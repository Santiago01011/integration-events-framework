/**
 * @description Public utility for publishing IntegrationEvent__e used by
 * the Integration Logs Framework. This class centralizes event publishing.
 *
 * Key responsibilities:
 *  - Provide a simple, developer-friendly method to publish events.
 *  - Safely truncate fields to the platform/event schema limits to avoid publish failures.
 *  - Enforce kill switch: If an integration is registered with Enabled=false, block emission.
 *
 * Contract (inputs/outputs):
 *  - Inputs: integrationCode, observationType, correlationId, parentEventId, context (JSON/String)
 *  - Output: publishes one IntegrationEvent__e to the EventBus (unless blocked by kill switch).
 *
 * Design decisions:
 *  - The class is designed to be used by other classes and is not intended to be instantiated directly. Hence, all methods are static.
 *  - Unregistered integration codes are ALLOWED to emit (developer-friendly for new integrations).
 *  - Only explicitly DISABLED integrations are blocked.
 *
 * Usage examples:
 *  // publish a simple event
 *  IntegrationEventPublisher.emit('SAP_ORDER', 'HTTP_REQUEST', 'corr-123', null, '{"url": "..."}');
 */
public without sharing class IntegrationEventPublisher {
  // Cache of disabled integration codes (loaded once per transaction)
  private static Set<String> disabledCodes;

  /**
   * @description Loads the set of disabled integration codes from Custom Metadata.
   */
  private static void loadDisabledCodes() {
    if (disabledCodes == null) {
      disabledCodes = new Set<String>();
      for (idhIntegration_Definition__mdt def : [
        SELECT IntegrationCode__c
        FROM idhIntegration_Definition__mdt
        WHERE Enabled__c = FALSE
      ]) {
        if (String.isNotBlank(def.IntegrationCode__c)) {
          disabledCodes.add(def.IntegrationCode__c.toUpperCase());
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
   * @description Canonical emitter: publishes a neutral observation with correlation.
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
      integrationCode,
      observationType,
      correlationId,
      parentEventId,
      JSON.serialize(contextMap)
    );
  }

  /**
   * @description Canonical emitter: publishes a neutral observation with correlation.
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
    if (isDisabled(integrationCode)) {
      return;
    }
    IntegrationEvent__e event = new IntegrationEvent__e(
      IntegrationCode__c = integrationCode?.left(100),
      ObservationType__c = observationType?.left(100),
      CorrelationId__c = correlationId?.left(80),
      ParentEventId__c = parentEventId?.left(80),
      Context__c = context?.left(32768),
      OccurredAt__c = Datetime.now()
    );

    Database.SaveResult result = EventBus.publish(event);

    if (!result.isSuccess()) {
      List<Database.Error> errors = result.getErrors();
      String message = 'Failed to publish IntegrationEvent__e';
      if (errors != null && !errors.isEmpty() && errors[0] != null) {
        message += ': ' + errors[0].getMessage();
      }
      throw new CalloutException(message);
    }
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
