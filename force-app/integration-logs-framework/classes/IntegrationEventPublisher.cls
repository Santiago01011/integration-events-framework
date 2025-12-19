/**
 * @description Public utility for publishing IntegrationEvent__e used by
 * the Integration Logs Framework. This class centralizes event publishing and
 * provides several overloads for common usages (errors, exceptions, informational messages).
 *
 * Key responsibilities:
 *  - Provide simple, developer-friendly methods to publish error and info events.
 *  - Safely truncate fields to the platform/event schema limits to avoid publish failures.
 *  - Mark events as processed/unprocessed based on the method called.
 *
 * Contract (inputs/outputs):
 *  - Inputs: context (String), message or Exception, optional stackTrace, payloadId, jobId, processedState
 *  - Output: publishes one IntegrationEvent__e to the EventBus.
 *
 * Design decisions:
 *  - The class is designed to be used by other classes and is not intended to be instantiated directly. Hence, all methods are static.
 *
 * Usage examples:
 *  // publish a simple error message
 *  IntegrationEventPublisher.publishError('ExecutingJob', 'An unexpected error occurred');
 *
 *  // publish with exception and payload id
 *  IntegrationEventPublisher.publishError('ExecutingJob', ex, 'payload-123');
 * 
 * // publish informational message
 *  IntegrationEventPublisher.publishInfo('DataSync', 'Data sync completed successfully', 'payload-456', 'job-789');
 */
public without sharing class IntegrationEventPublisher {

  private static final String LEGACY_ERROR_OBSERVATION = 'EXCEPTION_THROWN';
  private static final String LEGACY_INFO_OBSERVATION = 'RESPONSE_RECEIVED';

  /**
   * @description New neutral emitter that supports integration code, observation type, and correlation identifiers.
   * @param integrationCode Integration identifier from metadata.
   * @param observationType Fact-based observation type.
   * @param correlationId Correlation identifier to propagate across hops.
   * @param context Additional event context: keys supported are
   *  context, message, stackTrace, payloadId, jobId, source, parentEventId, processed.
   */
  public static void emit(
    String integrationCode,
    String observationType,
    String correlationId,
    Map<String, Object> context
  ) {
    Map<String, Object> safeContext = context == null ? new Map<String, Object>() : new Map<String, Object>(context);

    String ctx = (String) safeContext.get('context');
    String message = (String) safeContext.get('message');
    String stackTrace = (String) safeContext.get('stackTrace');
    String payloadId = (String) safeContext.get('payloadId');
    String jobId = (String) safeContext.get('jobId');
    String source = (String) safeContext.get('source');
    String parentEventId = (String) safeContext.get('parentEventId');
    Boolean processedState = (Boolean) safeContext.get('processed');

    publishEvent(
      ctx,
      message,
      stackTrace,
      payloadId,
      jobId,
      processedState,
      observationType,
      integrationCode,
      correlationId,
      parentEventId,
      source
    );
  }

  /**
   * @description Core method to publish an IntegrationEvent__e with all parameters.
   * This method handles field truncation and event publishing.
   * @param context The context in which the event is published.
   * @param errorMessage The error message to log.
   * @param stackTrace The stack trace associated
   * @param payloadId The associated payload identifier.
   * @param jobId The associated job identifier.
   * @param processedState Boolean indicating if the event is processed (true) or an error (false).
   * @param observationType Fact-based observation type.
   * @param integrationCode Integration code from metadata.
   * @param correlationId Correlation identifier for the event.
   * @param parentEventId Parent event identifier if applicable.
   * @param source Source system identifier.
   */
  public static void publishEvent(
    String context,
    String errorMessage,
    String stackTrace,
    String payloadId,
    String jobId,
    Boolean processedState,
    String observationType,
    String integrationCode,
    String correlationId,
    String parentEventId,
    String source
  ) {
    IntegrationEvent__e event = new IntegrationEvent__e(
      Context__c = context,
      EventMessage__c = errorMessage?.left(32000),
      StackTrace__c = stackTrace?.left(32000),
      PayloadId__c = payloadId?.left(100),
      JobId__c = jobId?.left(50),
      Processed__c = processedState,
      ObservationType__c = observationType?.left(100),
      IntegrationCode__c = integrationCode?.left(100),
      CorrelationId__c = correlationId?.left(80),
      ParentEventId__c = parentEventId?.left(80),
      Source__c = source?.left(50)
    );

    Database.SaveResult result = EventBus.publish(event);

    if (!result.isSuccess()) {
      List<Database.Error> errors = result.getErrors();
      String message = 'Failed to publish IntegrationEvent__e';
      if (errors != null && !errors.isEmpty() && errors[0] != null) {
        message += ': ' + errors[0].getMessage();
      }
      throw new EventBus.PublishException(message);
    }
  }

/**
 * Static Helpers for common publish scenarios.
 * These methods provide convenient wrappers for publishing error and info events.
 */
  public static void publishError(String context, String errorMessage, String stackTrace, String payloadId, String jobId) {
    publishEvent(context, errorMessage, stackTrace, payloadId, jobId, false, LEGACY_ERROR_OBSERVATION, null, null, null, null);
  }

  public static void publishError(String context, Exception ex, String payloadId) {
    publishEvent(context, ex.getMessage(), ex.getStackTraceString(), payloadId, null, false, LEGACY_ERROR_OBSERVATION, null, null, null, null);
  }

  public static void publishError(String context, String errorMessage) {
    publishEvent(context, errorMessage, null, null, null, false, LEGACY_ERROR_OBSERVATION, null, null, null, null);
  }

  public static void publishError(String context, Exception ex, String payloadId, String jobId) {
    publishEvent(context, ex.getMessage(), ex.getStackTraceString(), payloadId, jobId, false, LEGACY_ERROR_OBSERVATION, null, null, null, null);
  }

  public static void publishInfo(String context, String message, String payloadId, String jobId) {
    publishEvent(context, message, null, payloadId, jobId, true, LEGACY_INFO_OBSERVATION, null, null, null, null);
  }

  public static void publishInfo(String context, String message, String stackTrace, String payloadId, String jobId) {
    publishEvent(context, message, stackTrace, payloadId, jobId, true, LEGACY_INFO_OBSERVATION, null, null, null, null);
  }
}
