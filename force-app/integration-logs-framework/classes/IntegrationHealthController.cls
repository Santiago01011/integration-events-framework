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

  /**
   * @description Fetches severity distribution across all logs.
   * @return List<IntegrationHealthWrappers.SeverityCountEntry> Severity counts with percentages
   */
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.SeverityCountEntry> getSeverityCounts() {
    try {
      return IntegrationHealthService.getSeverityCounts();
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return new List<IntegrationHealthWrappers.SeverityCountEntry>();
    }
  }

  /**
   * @description Fetches top integrations by error count with trend indicators.
   * @param topN The maximum number of integrations to return
   * @return List<IntegrationHealthWrappers.TopErrorIntegration> Ranked error integrations
   */
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.TopErrorIntegration> getTopErrorIntegrations(
    Integer topN
  ) {
    try {
      return IntegrationHealthService.getTopErrorIntegrations(topN);
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return new List<IntegrationHealthWrappers.TopErrorIntegration>();
    }
  }

  /**
   * @description Fetches hourly trend data for sparkline visualization.
   * @param hours The number of hours to include in the trend
   * @return IntegrationHealthWrappers.HourlyTrendResult Hourly trend with direction and delta
   */
  @AuraEnabled(cacheable=false)
  public static IntegrationHealthWrappers.HourlyTrendResult getHourlyTrend(
    Integer hours
  ) {
    try {
      return IntegrationHealthService.getHourlyTrend(hours);
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return new IntegrationHealthWrappers.HourlyTrendResult();
    }
  }

  /**
   * @description Returns all active card plugins with their metadata.
   * @return List of PluginInfo wrappers for rendering in the Summary tab
   */
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.PluginInfo> getActiveCardPlugins() {
    List<IntegrationHealthWrappers.PluginInfo> plugins = new List<IntegrationHealthWrappers.PluginInfo>();
    List<IHD_Plugin__mdt> cardConfigs = IHD_PluginRegistry.getCardConfigs();

    for (IHD_Plugin__mdt config : cardConfigs) {
      Object pluginInstance = IHD_PluginRegistry.getInstance(config);
      if (
        pluginInstance == null || !(pluginInstance instanceof IHD_CardPlugin)
      ) {
        continue;
      }
      try {
        IHD_CardPlugin cardPlugin = (IHD_CardPlugin) pluginInstance;
        IntegrationHealthWrappers.PluginInfo info = new IntegrationHealthWrappers.PluginInfo();
        info.name = cardPlugin.getCardName();
        info.description = cardPlugin.getCardDescription();
        info.componentName = cardPlugin.getComponentName();
        info.order = cardPlugin.getOrder();
        info.data = null;
        plugins.add(info);
      } catch (Exception e) {
        System.debug(
          LoggingLevel.ERROR,
          'IntegrationHealthController: Error loading card plugin ' +
            config.DeveloperName +
            ': ' +
            e.getMessage()
        );
      }
    }

    return plugins;
  }

  /**
   * @description Returns all registered plugins from IHD_Plugin__mdt for the Admin tab.
   * @return List of PluginRegistryEntry wrappers sorted by display order
   */
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.PluginRegistryEntry> getRegisteredPlugins() {
    List<IntegrationHealthWrappers.PluginRegistryEntry> entries = new List<IntegrationHealthWrappers.PluginRegistryEntry>();
    List<IHD_Plugin__mdt> allPlugins = [
      SELECT
        DeveloperName,
        Label,
        PluginType__c,
        Enabled__c,
        Description__c,
        ApexClassName__c,
        LwcComponentName__c,
        DisplayOrder__c
      FROM IHD_Plugin__mdt
      WITH USER_MODE
      ORDER BY DisplayOrder__c ASC NULLS LAST, Label ASC
    ];

    for (IHD_Plugin__mdt plugin : allPlugins) {
      IntegrationHealthWrappers.PluginRegistryEntry entry = new IntegrationHealthWrappers.PluginRegistryEntry();
      entry.developerName = plugin.DeveloperName;
      entry.label = plugin.Label;
      entry.pluginType = plugin.PluginType__c;
      entry.enabled = plugin.Enabled__c;
      entry.description = plugin.Description__c;
      entry.apexClassName = plugin.ApexClassName__c;
      entry.lwcComponentName = plugin.LwcComponentName__c;
      entry.displayOrder = (Integer) plugin.DisplayOrder__c;
      entries.add(entry);
    }

    return entries;
  }

  /**
   * @description Returns data for a specific card plugin.
   * @param pluginName The plugin DeveloperName from IHD_Plugin__mdt
   * @return The plugin's data object
   */
  @AuraEnabled(cacheable=false)
  public static Object getCardPluginData(String pluginName) {
    List<IHD_Plugin__mdt> cardConfigs = IHD_PluginRegistry.getCardConfigs();
    for (IHD_Plugin__mdt config : cardConfigs) {
      if (config.DeveloperName == pluginName) {
        Object pluginInstance = IHD_PluginRegistry.getInstance(config);
        if (pluginInstance instanceof IHD_CardPlugin) {
          return ((IHD_CardPlugin) pluginInstance)
            .getData(new Map<String, Object>());
        }
      }
    }
    return null;
  }
}
