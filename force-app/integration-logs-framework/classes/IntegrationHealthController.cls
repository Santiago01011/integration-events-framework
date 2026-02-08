/**
 * @description Controller for the Integration Health Dashboard components.
 * Delegates logic to specialized service and selector classes.
 */
public with sharing class IntegrationHealthController {
  @AuraEnabled(cacheable=false)
  public static IntegrationHealthWrappers.IntegrationLogPage getRecentLogs(
    Integer pageSize,
    String search,
    String fromOccurredAtStr,
    String toOccurredAtStr,
    String lastOccurredAtStr,
    Id lastId,
    String correlationId,
    String observationType,
    String integrationCode
  ) {
    try {
      return IntegrationHealthService.getPagedLogs(
        pageSize,
        search,
        fromOccurredAtStr,
        toOccurredAtStr,
        lastOccurredAtStr,
        lastId,
        correlationId,
        observationType,
        integrationCode
      );
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return null;
    }
  }

  @AuraEnabled(cacheable=false)
  public static IntegrationHealthWrappers.LogDetailWrapper getLogDetail(
    Id logId
  ) {
    try {
      return IntegrationHealthService.getLogDetail(logId);
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return null;
    }
  }

  @AuraEnabled(cacheable=true)
  public static Boolean isAdminUser() {
    return IntegrationHealthSelector.isAdminUser();
  }

  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.IntegrationSummary> getIntegrationSummaries(
    Boolean includeUnregistered,
    Boolean expandByAttributes
  ) {
    try {
      return IntegrationHealthService.getIntegrationSummaries(
        includeUnregistered,
        expandByAttributes
      );
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return null;
    }
  }

  @AuraEnabled(cacheable=true)
  public static IntegrationHealthWrappers.FilterOptions getFilterOptions() {
    try {
      return IntegrationHealthService.getFilterOptions();
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return null;
    }
  }

  @AuraEnabled(cacheable=true)
  public static String getEventChannel() {
    return IntegrationHealthService.getEventChannel();
  }

  @AuraEnabled(cacheable=true)
  public static List<IntegrationHealthWrappers.RegistryEntry> getRegistryInfo() {
    try {
      return IntegrationHealthService.getRegistryInfo();
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return null;
    }
  }

  @AuraEnabled
  public static String deployRegistryEntry(
    String integrationCode,
    String label,
    String groupName,
    String direction,
    String transport,
    Boolean isEnabled
  ) {
    try {
      return IntegrationRegistryService.deployRegistryEntry(
        integrationCode,
        label,
        groupName,
        direction,
        transport,
        isEnabled
      );
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return null;
    }
  }

  @AuraEnabled
  public static void deleteLog(Id logId) {
    try {
      IntegrationHealthService.deleteLog(logId);
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
    }
  }

  @AuraEnabled
  public static void updateLogObservation(Id logId, String newType) {
    try {
      IntegrationHealthService.updateLogObservation(logId, newType);
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
    }
  }
}
