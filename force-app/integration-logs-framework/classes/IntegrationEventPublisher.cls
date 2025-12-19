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
  /**
   * @description Core method to publish an IntegrationEvent__e with all parameters.
   * This method handles field truncation and event publishing.
   * @param context The context in which the event is published.
   * @param errorMessage The error message to log.
   * @param stackTrace The stack trace associated
   * @param payloadId The associated payload identifier.
   * @param jobId The associated job identifier.
   * @param processedState Boolean indicating if the event is processed (true) or an error (false).
   */
  public static void publishEvent(
    String context,
    String errorMessage,
    String stackTrace,
    String payloadId,
    String jobId,
    Boolean processedState
  ) {
    IntegrationEvent__e event = new IntegrationEvent__e(
      Context__c = context,
      EventMessage__c = errorMessage?.left(32000),
      StackTrace__c = stackTrace?.left(32000),
      PayloadId__c = payloadId?.left(100),
      JobId__c = jobId?.left(50),
      Processed__c = processedState
    );

    Database.SaveResult result = EventBus.publish(event);

    if (!result.isSuccess()) {
      System.debug(
        LoggingLevel.ERROR,
        'Failed to publish IntegrationEvent__e: ' + result.getErrors()
      );
    }
  }

/**
 * Static Helpers for common publish scenarios.
 * These methods provide convenient wrappers for publishing error and info events.
 */
  public static void publishError(String context, String errorMessage, String stackTrace, String payloadId, String jobId) {
    publishEvent(context, errorMessage, stackTrace, payloadId, jobId, false);
  }

  public static void publishError(String context, Exception ex, String payloadId) {
    publishEvent(context, ex.getMessage(), ex.getStackTraceString(), payloadId, null, false);
  }

  public static void publishError(String context, String errorMessage) {
    publishEvent(context, errorMessage, null, null, null, false);
  }

  public static void publishError(String context, Exception ex, String payloadId, String jobId) {
    publishEvent(context, ex.getMessage(), ex.getStackTraceString(), payloadId, jobId, false);
  }

  public static void publishInfo(String context, String message, String payloadId, String jobId) {
    publishEvent(context, message, null, payloadId, jobId, true);
  }

  public static void publishInfo(String context, String message, String stackTrace, String payloadId, String jobId) {
    publishEvent(context, message, stackTrace, payloadId, jobId, true);
  }
}
