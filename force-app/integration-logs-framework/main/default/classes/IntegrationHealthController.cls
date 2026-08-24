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

  /**
   * @description Checks whether the current user has the IEF_Manage_Plugins custom permission.
   * Used to gate Admin tab visibility and plugin toggle operations.
   * @return True if the user can manage plugins
   */
  @AuraEnabled(cacheable=true)
  public static Boolean canManagePlugins() {
    return FeatureManagement.checkPermission('IEF_Manage_Plugins');
  }

  /**
   * @description Checks whether the current user can update Integration_Log__c.ObservationType__c.
   * Used to enable manual status changes only when USER_MODE DML would succeed.
   * @return True if the current user can edit the observation type field
   */
  @AuraEnabled(cacheable=true)
  public static Boolean canEditLogObservationType() {
    return IntegrationHealthService.canEditLogObservationType();
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
   * @description Returns all active card plugins with their metadata.
   * Supports both Apex-based plugins (implementing IEF_CardPlugin) and
   * LWC-only plugins (registered via shell components with ApexClassName__c = 'N/A').
   * Uses IEF_PluginRegistry.resolve() so failures surface with reason instead of silent null.
   * @return List of PluginInfo wrappers for rendering in the Summary tab
   */
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.PluginInfo> getActiveCardPlugins() {
    List<IntegrationHealthWrappers.PluginInfo> plugins = new List<IntegrationHealthWrappers.PluginInfo>();
    List<IEF_Plugin__mdt> cardConfigs = IEF_PluginRegistry.getCardConfigs();

    for (IEF_Plugin__mdt config : cardConfigs) {
      IntegrationHealthWrappers.PluginInfo info = new IntegrationHealthWrappers.PluginInfo();
      info.developerName = config.DeveloperName;
      info.label = config.Label;
      info.cardLocation = config.CardLocation__c;
      info.data = null;
      info.reason = null;

      Boolean hasApexClass =
        String.isNotBlank(config.ApexClassName__c) &&
        config.ApexClassName__c != 'N/A' &&
        config.ApexClassName__c != 'n/a';

      if (hasApexClass) {
        IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(config);
        if (res.status == 'ACTIVE' && res.instance instanceof IEF_CardPlugin) {
          IEF_CardPlugin cardPlugin = (IEF_CardPlugin) res.instance;
          info.name = cardPlugin.getCardName();
          if (String.isBlank(info.label)) {
            info.label = info.name;
          }
          info.description = cardPlugin.getCardDescription();
          info.componentName = cardPlugin.getComponentName();
          info.order = cardPlugin.getOrder();
          Integer gridSpanValue = config.Grid_Span__c != null
            ? Integer.valueOf(config.Grid_Span__c)
            : 1;
          info.gridSpan = gridSpanValue;
          plugins.add(info);
          continue;
        }
        // Fallback for FAILED/ORPHAN or non-card instance
        info.name = String.isNotBlank(info.name) ? info.name : config.Label;
        info.description = config.Description__c;
        info.componentName = config.LwcComponentName__c;
        info.order = config.DisplayOrder__c != null
          ? (Integer) config.DisplayOrder__c
          : 0;
        Integer gridSpanValue = config.Grid_Span__c != null
          ? Integer.valueOf(config.Grid_Span__c)
          : 1;
        info.gridSpan = gridSpanValue;
        if (
          res.status == 'FAILED' ||
          res.status == 'ORPHAN' ||
          res.status == 'SKIPPED_VERSION_MISMATCH' ||
          res.status == 'SKIPPED'
        ) {
          info.reason = res.reason;
        } else if (
          res.status == 'ACTIVE' && !(res.instance instanceof IEF_CardPlugin)
        ) {
          info.reason =
            'Plugin ' +
            config.DeveloperName +
            ' does not implement IEF_CardPlugin';
        } else if (String.isBlank(info.reason)) {
          info.reason =
            'Card provider not available: ' + config.ApexClassName__c;
        }
        if (String.isBlank(info.reason) && String.isNotBlank(res.reason)) {
          info.reason = res.reason;
        }
        plugins.add(info);
      } else {
        // LWC-only plugin (registered via shell component) — still check version guard
        IEF_PluginRegistry.Resolution lwcRes = IEF_PluginRegistry.resolve(
          config
        );
        info.name = config.Label;
        if (String.isBlank(info.label)) {
          info.label = info.name;
        }
        info.description = config.Description__c;
        info.componentName = config.LwcComponentName__c;
        info.order = config.DisplayOrder__c != null
          ? (Integer) config.DisplayOrder__c
          : 0;
        Integer gridSpanValue = config.Grid_Span__c != null
          ? Integer.valueOf(config.Grid_Span__c)
          : 1;
        info.gridSpan = gridSpanValue;
        if (
          lwcRes.status == 'SKIPPED_VERSION_MISMATCH' ||
          lwcRes.status == 'SKIPPED'
        ) {
          info.reason = lwcRes.reason;
        }
        plugins.add(info);
      }
    }

    return plugins;
  }

  /**
   * @description Returns effective composition info for every plugin registry row.
   * Per row: resolved target, card order, instantiation status (ACTIVE/ACTIVE_LWC/FAILED/ORPHAN), and failure reason.
   * Never throws for orphan rows — they are flagged with ORPHAN status.
   * @return List of PluginCompositionEntry sorted by DisplayOrder
   */
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.PluginCompositionEntry> getCompositionInfo() {
    try {
      List<IntegrationHealthWrappers.PluginCompositionEntry> entries = new List<IntegrationHealthWrappers.PluginCompositionEntry>();
      List<IEF_Plugin__mdt> allPlugins = [
        SELECT
          DeveloperName,
          Label,
          PluginType__c,
          ApexClassName__c,
          LwcComponentName__c,
          DisplayOrder__c,
          Enabled__c,
          Description__c,
          CardLocation__c,
          SObjectType__c,
          DeclaredFields__c,
          Grid_Span__c
        FROM IEF_Plugin__mdt
        ORDER BY DisplayOrder__c ASC NULLS LAST, DeveloperName ASC
      ];

      for (IEF_Plugin__mdt cfg : allPlugins) {
        IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(cfg);
        IntegrationHealthWrappers.PluginCompositionEntry e = new IntegrationHealthWrappers.PluginCompositionEntry();
        e.developerName = cfg.DeveloperName;
        e.label = cfg.Label;
        e.pluginType = cfg.PluginType__c;
        e.apexClassName = cfg.ApexClassName__c;
        e.lwcComponentName = cfg.LwcComponentName__c;
        e.displayOrder = cfg.DisplayOrder__c != null
          ? (Integer) cfg.DisplayOrder__c
          : null;
        e.status = res.status;
        e.reason = res.reason;
        e.enabled = cfg.Enabled__c;
        e.contractVersion = null;
        // When Contract_Version__c field exists (D2A), populate it dynamically to stay deployable before that field lands
        try {
          Object cv = cfg.get('Contract_Version__c');
          if (cv != null) {
            e.contractVersion = String.valueOf(cv);
          }
        } catch (Exception ignored) {
        }
        entries.add(e);
      }
      return entries;
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return new List<IntegrationHealthWrappers.PluginCompositionEntry>();
    }
  }

  /**
   * @description Returns all registered plugins from IEF_Plugin__mdt for the Admin tab.
   * @return List of PluginRegistryEntry wrappers sorted by display order
   */
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.PluginRegistryEntry> getRegisteredPlugins() {
    List<IntegrationHealthWrappers.PluginRegistryEntry> entries = new List<IntegrationHealthWrappers.PluginRegistryEntry>();
    List<IEF_Plugin__mdt> allPlugins = [
      SELECT
        DeveloperName,
        Label,
        PluginType__c,
        Enabled__c,
        Description__c,
        ApexClassName__c,
        LwcComponentName__c,
        DisplayOrder__c
      FROM IEF_Plugin__mdt
      WITH USER_MODE
      ORDER BY DisplayOrder__c ASC NULLS LAST, Label ASC
    ];

    for (IEF_Plugin__mdt plugin : allPlugins) {
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
   * @description Returns data for a specific card plugin with filter context.
   * @param pluginName The plugin DeveloperName from IEF_Plugin__mdt
   * @param filters Dashboard filter context (search, observationType, integrationCode, etc.)
   * @return The plugin's data object
   */
  @AuraEnabled(cacheable=false)
  public static Object getCardPluginData(
    String pluginName,
    Map<String, Object> filters
  ) {
    List<IEF_Plugin__mdt> cardConfigs = IEF_PluginRegistry.getCardConfigs();
    for (IEF_Plugin__mdt config : cardConfigs) {
      if (config.DeveloperName == pluginName) {
        IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(config);
        if (res.status == 'ACTIVE' && res.instance instanceof IEF_CardPlugin) {
          return ((IEF_CardPlugin) res.instance)
            .getData(filters != null ? filters : new Map<String, Object>());
        }
        return null;
      }
    }
    return null;
  }

  /**
   * @description Clears the plugin registry cache so the next query is fresh.
   * Call this after metadata changes or from the Admin panel refresh.
   */
  @AuraEnabled
  public static void refreshPluginCache() {
    try {
      IEF_PluginRegistry.clearCache();
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
    }
  }

  /**
   * @description Toggles a plugin's Enabled__c via Metadata API deployment.
   * @param developerName The DeveloperName of the IEF_Plugin__mdt record
   * @param enabled The desired enabled state
   * @return The deployment job ID
   */
  @AuraEnabled
  public static String togglePluginEnabled(
    String developerName,
    Boolean enabled
  ) {
    try {
      if (!FeatureManagement.checkPermission('IEF_Manage_Plugins')) {
        throw new AuraHandledException(
          'Insufficient privileges. You need the IEF_Manage_Plugins permission to manage plugins.'
        );
      }
      return IEF_PluginRegistry.togglePlugin(developerName, enabled);
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return null;
    }
  }
}
