/**
 * @description Singleton registry that discovers and manages plugin implementations.
 * Reads IEF_Plugin__mdt records and instantiates plugins via Type.forName().
 * Caches active plugin instances per plugin type.
 */
public with sharing class IEF_PluginRegistry {
  @TestVisible
  private static Map<String, List<IEF_Plugin__mdt>> cachedConfigs;
  @TestVisible
  private static Map<String, Object> cachedInstances;
  @TestVisible
  private static Map<String, Resolution> cachedResolutions;
  @TestVisible
  private static Exception testTogglePluginException;

  /**
   * @description Resolution result for a plugin config. Carries instance plus status and reason.
   * Status values: ACTIVE, ACTIVE_LWC, FAILED, ORPHAN, SKIPPED_VERSION_MISMATCH
   */
  public class Resolution {
    @AuraEnabled
    public Object instance { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public String reason { get; set; }

    public Resolution(Object instance, String status, String reason) {
      this.instance = instance;
      this.status = status;
      this.reason = reason;
    }
  }

  /**
   * @description Returns all enabled plugin configurations for a given type.
   * @param pluginType The plugin type string (TRIGGER, SERVICE, FIELD, CARD)
   * @return List of enabled IEF_Plugin__mdt records, sorted by DisplayOrder__c
   */
  public static List<IEF_Plugin__mdt> getConfigs(String pluginType) {
    if (cachedConfigs == null) {
      cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    }
    if (!cachedConfigs.containsKey(pluginType)) {
      List<IEF_Plugin__mdt> configs = [
        SELECT
          DeveloperName,
          Label,
          PluginType__c,
          ApexClassName__c,
          Enabled__c,
          DisplayOrder__c,
          Description__c,
          LwcComponentName__c,
          SObjectType__c,
          DeclaredFields__c,
          CardLocation__c,
          Grid_Span__c
        FROM IEF_Plugin__mdt
        WHERE Enabled__c = TRUE AND PluginType__c = :pluginType
        ORDER BY DisplayOrder__c ASC NULLS LAST, DeveloperName ASC
      ];
      cachedConfigs.put(pluginType, configs);
    }
    return cachedConfigs.get(pluginType);
  }

  /**
   * @description Resolves a plugin config to a Resolution. Never caches a silent null;
   * failures are recorded with reason and are re-attemptable after clearCache().
   * Orphan detection via Type.forName == null.
   * @param config The plugin configuration record
   * @return Resolution with instance, status, reason
   */
  public static Resolution resolve(IEF_Plugin__mdt config) {
    if (config == null) {
      return new Resolution(null, 'FAILED', 'Null plugin config');
    }
    String apexClassName = config.ApexClassName__c;
    if (String.isBlank(apexClassName)) {
      return new Resolution(null, 'ORPHAN', 'Apex class not specified');
    }

    // D2A: contract version guard — check before any instantiation or caching
    String contractVersionStr = null;
    Decimal contractVersionDec = null;
    Boolean hasVersionField = false;
    try {
      Object cv = config.get('Contract_Version__c');
      hasVersionField = true;
      if (cv != null) {
        contractVersionStr = String.valueOf(cv);
        if (cv instanceof Decimal) {
          contractVersionDec = (Decimal) cv;
        } else if (cv instanceof Double) {
          contractVersionDec = Decimal.valueOf(String.valueOf(cv));
        } else {
          try {
            contractVersionDec = Decimal.valueOf(contractVersionStr);
          } catch (Exception e) {
            contractVersionDec = null;
          }
        }
      }
    } catch (Exception e) {
      hasVersionField = false;
    }
    if (hasVersionField) {
      Boolean compatible;
      if (contractVersionDec != null) {
        compatible = IEF_PluginContract.isCompatible(contractVersionDec);
      } else {
        compatible = IEF_PluginContract.isCompatible(contractVersionStr);
      }
      if (!compatible) {
        String displayVersion = String.isBlank(contractVersionStr)
          ? 'null'
          : contractVersionStr;
        String reason =
          'Contract version mismatch: plugin ' +
          config.DeveloperName +
          ' requires ' +
          displayVersion +
          ' but host supports ' +
          IEF_PluginContract.SUPPORTED_MAJOR +
          '.x';
        String versionCacheKey = apexClassName == 'N/A' ||
          apexClassName == 'n/a'
          ? apexClassName + ':' + config.DeveloperName
          : apexClassName;
        if (cachedResolutions == null) {
          cachedResolutions = new Map<String, Resolution>();
        }
        if (cachedResolutions.containsKey(versionCacheKey)) {
          return cachedResolutions.get(versionCacheKey);
        }
        Resolution skipped = new Resolution(
          null,
          'SKIPPED_VERSION_MISMATCH',
          reason
        );
        cachedResolutions.put(versionCacheKey, skipped);
        if (cachedInstances == null) {
          cachedInstances = new Map<String, Object>();
        }
        cachedInstances.put(versionCacheKey, null);
        try {
          IntegrationEventPublisher.emit(
            'FRAMEWORK_INTERNAL',
            'PLUGIN_SKIPPED_VERSION_MISMATCH',
            config.DeveloperName,
            null,
            reason
          );
        } catch (Exception emitEx) {
        }
        return skipped;
      }
    }

    if (apexClassName == 'N/A' || apexClassName == 'n/a') {
      String cacheKey = apexClassName + ':' + config.DeveloperName;
      if (cachedResolutions == null) {
        cachedResolutions = new Map<String, Resolution>();
      }
      if (cachedResolutions.containsKey(cacheKey)) {
        return cachedResolutions.get(cacheKey);
      }
      Resolution r = new Resolution(null, 'ACTIVE_LWC', null);
      cachedResolutions.put(cacheKey, r);
      return r;
    }

    String cacheKey = apexClassName;
    if (cachedResolutions == null) {
      cachedResolutions = new Map<String, Resolution>();
    }
    if (cachedResolutions.containsKey(cacheKey)) {
      return cachedResolutions.get(cacheKey);
    }
    // Backward-compat: promote legacy cachedInstances entry if present
    if (cachedInstances != null && cachedInstances.containsKey(cacheKey)) {
      Object legacy = cachedInstances.get(cacheKey);
      if (legacy != null) {
        Resolution promoted = new Resolution(legacy, 'ACTIVE', null);
        cachedResolutions.put(cacheKey, promoted);
        return promoted;
      }
    }

    Resolution result;
    try {
      Type pluginType = Type.forName(apexClassName);
      if (pluginType == null) {
        result = new Resolution(
          null,
          'ORPHAN',
          'Apex class not found: ' + apexClassName
        );
      } else {
        Object instance = pluginType.newInstance();
        result = new Resolution(instance, 'ACTIVE', null);
      }
    } catch (Exception e) {
      String reason =
        'Failed to instantiate ' +
        apexClassName +
        ': ' +
        e.getMessage();
      result = new Resolution(null, 'FAILED', reason);
    }

    cachedResolutions.put(cacheKey, result);
    // Keep legacy map in sync for callers that still read it directly
    if (cachedInstances == null) {
      cachedInstances = new Map<String, Object>();
    }
    cachedInstances.put(cacheKey, result.instance);

    return result;
  }

  /**
   * @description Returns an instantiated plugin for the given configuration.
   * Uses Type.forName() for dynamic class resolution.
   * @param config The plugin configuration record
   * @return The instantiated plugin object, or null if not found
   * @deprecated Use resolve() to get status and reason. This method delegates to resolve().
   */
  public static Object getInstance(IEF_Plugin__mdt config) {
    Resolution res = resolve(config);
    return res.instance;
  }

  /**
   * @description Returns all enabled trigger plugin configs for a given SObject.
   * @param sobjectType The SObject API name
   * @return Filtered list of trigger plugins for this SObject
   */
  public static List<IEF_Plugin__mdt> getTriggerConfigs(String sobjectType) {
    List<IEF_Plugin__mdt> allTriggerConfigs = getConfigs(
      IEF_PluginType.TRIGGER.name()
    );
    if (String.isBlank(sobjectType)) {
      return allTriggerConfigs;
    }
    List<IEF_Plugin__mdt> filtered = new List<IEF_Plugin__mdt>();
    for (IEF_Plugin__mdt config : allTriggerConfigs) {
      if (config.SObjectType__c == sobjectType) {
        filtered.add(config);
      }
    }
    return filtered;
  }

  /**
   * @description Returns all enabled card plugin configs.
   * @return Sorted list of card plugins
   */
  public static List<IEF_Plugin__mdt> getCardConfigs() {
    return getConfigs(IEF_PluginType.CARD.name());
  }

  /**
   * @description Returns all enabled field plugin configs.
   * @return List of field plugins
   */
  public static List<IEF_Plugin__mdt> getFieldConfigs() {
    return getConfigs(IEF_PluginType.FIELD.name());
  }

  /**
   * @description Clears the cached configs and instances.
   * Call this after metadata changes to force fresh queries.
   */
  public static void clearCache() {
    cachedConfigs = null;
    cachedInstances = null;
    cachedResolutions = null;
  }

  /**
   * @description Returns all active plugin DeveloperNames across all types.
   * @return List of enabled plugin DeveloperNames
   */
  public static List<String> getActivePluginNames() {
    List<String> names = new List<String>();
    for (IEF_PluginType pt : IEF_PluginType.values()) {
      for (IEF_Plugin__mdt config : getConfigs(pt.name())) {
        names.add(config.DeveloperName);
      }
    }
    return names;
  }

  /**
   * @description Toggles a plugin's Enabled__c field via Metadata API deployment.
   * Asynchronously updates the custom metadata record. Defense-in-depth: also checks permission.
   * @param developerName The DeveloperName of the IEF_Plugin__mdt record
   * @param enabled The desired enabled state
   * @return The async deployment job ID
   */
  public static String togglePlugin(String developerName, Boolean enabled) {
    if (!FeatureManagement.checkPermission('IEF_Manage_Plugins')) {
      throw new AuraHandledException(
        'Insufficient privileges. You need the IEF_Manage_Plugins permission to manage plugins.'
      );
    }

    if (Test.isRunningTest() && testTogglePluginException != null) {
      Exception seamException = testTogglePluginException;
      testTogglePluginException = null;
      throw seamException;
    }

    // Query the full record
    List<IEF_Plugin__mdt> records = [
      SELECT
        Id,
        DeveloperName,
        Label,
        PluginType__c,
        ApexClassName__c,
        DisplayOrder__c,
        Description__c,
        LwcComponentName__c,
        SObjectType__c,
        DeclaredFields__c,
        CardLocation__c
      FROM IEF_Plugin__mdt
      WHERE DeveloperName = :developerName
      WITH USER_MODE
      LIMIT 1
    ];

    if (records.isEmpty()) {
      throw new IllegalArgumentException('Plugin not found: ' + developerName);
    }

    IEF_Plugin__mdt record = records[0];

    // Build metadata deployment
    Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
    customMetadata.fullName = 'IEF_Plugin__mdt.' + developerName;
    customMetadata.label = record.Label;

    // Add field values
    Metadata.CustomMetadataValue field;

    field = new Metadata.CustomMetadataValue();
    field.field = 'PluginType__c';
    field.value = record.PluginType__c;
    customMetadata.values.add(field);

    field = new Metadata.CustomMetadataValue();
    field.field = 'ApexClassName__c';
    field.value = record.ApexClassName__c;
    customMetadata.values.add(field);

    field = new Metadata.CustomMetadataValue();
    field.field = 'Enabled__c';
    field.value = enabled;
    customMetadata.values.add(field);

    if (record.DisplayOrder__c != null) {
      field = new Metadata.CustomMetadataValue();
      field.field = 'DisplayOrder__c';
      field.value = String.valueOf(record.DisplayOrder__c);
      customMetadata.values.add(field);
    }

    if (record.Description__c != null) {
      field = new Metadata.CustomMetadataValue();
      field.field = 'Description__c';
      field.value = record.Description__c;
      customMetadata.values.add(field);
    }

    if (record.LwcComponentName__c != null) {
      field = new Metadata.CustomMetadataValue();
      field.field = 'LwcComponentName__c';
      field.value = record.LwcComponentName__c;
      customMetadata.values.add(field);
    }

    if (record.SObjectType__c != null) {
      field = new Metadata.CustomMetadataValue();
      field.field = 'SObjectType__c';
      field.value = record.SObjectType__c;
      customMetadata.values.add(field);
    }

    if (record.DeclaredFields__c != null) {
      field = new Metadata.CustomMetadataValue();
      field.field = 'DeclaredFields__c';
      field.value = record.DeclaredFields__c;
      customMetadata.values.add(field);
    }

    if (record.CardLocation__c != null) {
      field = new Metadata.CustomMetadataValue();
      field.field = 'CardLocation__c';
      field.value = record.CardLocation__c;
      customMetadata.values.add(field);
    }

    // Deploy with callback to clear cache
    Metadata.DeployContainer container = new Metadata.DeployContainer();
    container.addMetadata(customMetadata);

    PluginDeployCallback callback = new PluginDeployCallback();
    Id jobId;
    if (Test.isRunningTest()) {
      jobId = '0Af000000000001AAA';
    } else {
      jobId = Metadata.Operations.enqueueDeployment(container, callback);
    }
    return String.valueOf(jobId);
  }

  /**
   * @description Callback for async metadata deployment. Clears cache on completion.
   */
  public class PluginDeployCallback implements Metadata.DeployCallback {
    public void handleResult(
      Metadata.DeployResult result,
      Metadata.DeployCallbackContext context
    ) {
      // Clear cache regardless of success/failure to ensure fresh state
      clearCache();

      if (result.status != Metadata.DeployStatus.Succeeded) {
        String message = buildErrorMessage(result);
        // Publisher error event so it surfaces in the UI logs
        IntegrationEventPublisher.handleControllerError(message);
      }
    }

    private String buildErrorMessage(Metadata.DeployResult result) {
      List<String> errorParts = new List<String>();

      if (String.isNotBlank(result.errorMessage)) {
        errorParts.add(result.errorMessage);
      }

      if (result.details != null && result.details.componentFailures != null) {
        for (
          Metadata.DeployMessage failure : result.details.componentFailures
        ) {
          String componentError = '';
          if (String.isNotBlank(failure.fullName)) {
            componentError += '[' + failure.fullName + '] ';
          }
          if (String.isNotBlank(failure.problem)) {
            componentError += failure.problem;
          }
          if (String.isNotBlank(componentError)) {
            errorParts.add(componentError);
          }
        }
      }

      if (errorParts.isEmpty()) {
        return 'Plugin deployment failed with status: ' + result.status;
      }

      return 'Plugin deployment failed: ' + String.join(errorParts, '; ');
    }
  }
}
