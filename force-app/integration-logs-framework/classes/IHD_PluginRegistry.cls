/**
 * @description Singleton registry that discovers and manages plugin implementations.
 * Reads IHD_Plugin__mdt records and instantiates plugins via Type.forName().
 * Caches active plugin instances per plugin type.
 */
public with sharing class IHD_PluginRegistry {
  @TestVisible
  private static Map<String, List<IHD_Plugin__mdt>> cachedConfigs;
  @TestVisible
  private static Map<String, Object> cachedInstances;

  /**
   * @description Returns all enabled plugin configurations for a given type.
   * @param pluginType The plugin type string (TRIGGER, SERVICE, FIELD, CARD)
   * @return List of enabled IHD_Plugin__mdt records, sorted by DisplayOrder__c
   */
  public static List<IHD_Plugin__mdt> getConfigs(String pluginType) {
    if (cachedConfigs == null) {
      cachedConfigs = new Map<String, List<IHD_Plugin__mdt>>();
    }
    if (!cachedConfigs.containsKey(pluginType)) {
      List<IHD_Plugin__mdt> configs = [
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
          CardLocation__c
        FROM IHD_Plugin__mdt
        WHERE Enabled__c = TRUE AND PluginType__c = :pluginType
        ORDER BY DisplayOrder__c ASC NULLS LAST, DeveloperName ASC
      ];
      cachedConfigs.put(pluginType, configs);
    }
    return cachedConfigs.get(pluginType);
  }

  /**
   * @description Returns an instantiated plugin for the given configuration.
   * Uses Type.forName() for dynamic class resolution.
   * @param config The plugin configuration record
   * @return The instantiated plugin object, or null if not found
   */
  public static Object getInstance(IHD_Plugin__mdt config) {
    if (cachedInstances == null) {
      cachedInstances = new Map<String, Object>();
    }
    String cacheKey = config.ApexClassName__c;
    if (!cachedInstances.containsKey(cacheKey)) {
      Object instance = null;
      try {
        Type pluginType = Type.forName(config.ApexClassName__c);
        if (pluginType != null) {
          instance = pluginType.newInstance();
        }
      } catch (Exception e) {
        System.debug(
          LoggingLevel.WARN,
          'IHD_PluginRegistry: Failed to instantiate ' +
            config.DeveloperName +
            ' (' +
            config.ApexClassName__c +
            '): ' +
            e.getMessage()
        );
      }
      cachedInstances.put(cacheKey, instance);
    }
    return cachedInstances.get(cacheKey);
  }

  /**
   * @description Returns all enabled trigger plugin configs for a given SObject.
   * @param sobjectType The SObject API name
   * @return Filtered list of trigger plugins for this SObject
   */
  public static List<IHD_Plugin__mdt> getTriggerConfigs(String sobjectType) {
    List<IHD_Plugin__mdt> allTriggerConfigs = getConfigs('TRIGGER');
    if (String.isBlank(sobjectType)) {
      return allTriggerConfigs;
    }
    List<IHD_Plugin__mdt> filtered = new List<IHD_Plugin__mdt>();
    for (IHD_Plugin__mdt config : allTriggerConfigs) {
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
  public static List<IHD_Plugin__mdt> getCardConfigs() {
    return getConfigs('CARD');
  }

  /**
   * @description Returns all enabled field plugin configs.
   * @return List of field plugins
   */
  public static List<IHD_Plugin__mdt> getFieldConfigs() {
    return getConfigs('FIELD');
  }

  /**
   * @description Clears the cached configs and instances.
   * Call this after metadata changes to force fresh queries.
   */
  public static void clearCache() {
    cachedConfigs = null;
    cachedInstances = null;
  }

  /**
   * @description Returns all active plugin DeveloperNames across all types.
   * @return List of enabled plugin DeveloperNames
   */
  public static List<String> getActivePluginNames() {
    List<String> names = new List<String>();
    for (
      String pluginType : new List<String>{
        'TRIGGER',
        'SERVICE',
        'FIELD',
        'CARD'
      }
    ) {
      for (IHD_Plugin__mdt config : getConfigs(pluginType)) {
        names.add(config.DeveloperName);
      }
    }
    return names;
  }

  /**
   * @description Toggles a plugin's Enabled__c field via Metadata API deployment.
   * Asynchronously updates the custom metadata record. Defense-in-depth: also checks permission.
   * @param developerName The DeveloperName of the IHD_Plugin__mdt record
   * @param enabled The desired enabled state
   * @return The async deployment job ID
   */
  public static String togglePlugin(String developerName, Boolean enabled) {
    if (!FeatureManagement.checkPermission('IHD_Manage_Plugins')) {
      throw new AuraHandledException(
        'Insufficient privileges. You need the IHD_Manage_Plugins permission to manage plugins.'
      );
    }

    // Query the full record
    List<IHD_Plugin__mdt> records = [
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
      FROM IHD_Plugin__mdt
      WHERE DeveloperName = :developerName
      WITH USER_MODE
      LIMIT 1
    ];

    if (records.isEmpty()) {
      throw new IllegalArgumentException('Plugin not found: ' + developerName);
    }

    IHD_Plugin__mdt record = records[0];

    // Build metadata deployment
    Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
    customMetadata.fullName = 'IHD_Plugin__mdt.' + developerName;
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
