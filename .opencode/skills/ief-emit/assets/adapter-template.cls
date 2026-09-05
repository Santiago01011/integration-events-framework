/**
 * Thin adapter: the ONLY class in a consuming org that references
 * IntegrationEventPublisher. All business code calls this adapter.
 * Replace publishWithFallback body when the IEF package is confirmed installed.
 */
public with sharing class IntegrationEventsDispatcher {
  @TestVisible
  private static Boolean frameworkInstalled = true;

  /**
   * Map a domain event to the IEF canonical emit signature.
   * eventNames use UPPER_SNAKE observation types registered in
   * idhIntegration_Evaluation_Rule__mdt.
   */
  public static void publish(
    String integrationCode,
    String observationType,
    String correlationId,
    String parentEventId,
    Map<String, Object> payload
  ) {
    if (
      String.isBlank(integrationCode) ||
      String.isBlank(observationType) ||
      payload == null ||
      payload.isEmpty()
    ) {
      return;
    }
    if (!frameworkInstalled) {
      System.debug(
        LoggingLevel.INFO,
        '[IntegrationEventsDispatcher] ' + observationType + ' ' + payload
      );
      return;
    }
    try {
      IntegrationEventPublisher.emit(
        integrationCode,
        observationType,
        correlationId,
        parentEventId,
        payload
      );
    } catch (Exception e) {
      // Never let observability break the business flow
      System.debug(
        LoggingLevel.ERROR,
        '[IntegrationEventsDispatcher] emit failed: ' + e.getMessage()
      );
    }
  }

  /**
   * Convenience overload for SObject payloads.
   */
  public static void publish(
    String integrationCode,
    String observationType,
    String correlationId,
    SObject record
  ) {
    if (record == null) {
      return;
    }
    publish(
      integrationCode,
      observationType,
      correlationId,
      null,
      (Map<String, Object>) JSON.deserialize(
        JSON.serialize(record.getPopulatedFieldsAsMap()),
        Map<String, Object>.class
      )
    );
  }
}
