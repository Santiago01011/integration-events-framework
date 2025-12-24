/**
 * @description Public utility for publishing IntegrationEvent__e used by
 * the Integration Logs Framework. This class centralizes event publishing.
 *
 * Key responsibilities:
 *  - Provide a simple, developer-friendly method to publish events.
 *  - Safely truncate fields to the platform/event schema limits to avoid publish failures.
 *
 * Contract (inputs/outputs):
 *  - Inputs: integrationCode, observationType, correlationId, parentEventId, context (JSON/String)
 *  - Output: publishes one IntegrationEvent__e to the EventBus.
 *
 * Design decisions:
 *  - The class is designed to be used by other classes and is not intended to be instantiated directly. Hence, all methods are static.
 *
 * Usage examples:
 *  // publish a simple event
 *  IntegrationEventPublisher.emit('SAP_ORDER', 'HTTP_REQUEST', 'corr-123', null, '{"url": "..."}');
 */
public without sharing class IntegrationEventPublisher {

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
      throw new AuraHandledException(message);
    }
  }
}
