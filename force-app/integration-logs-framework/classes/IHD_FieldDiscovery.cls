/**
 * @description Utility for discovering custom fields declared by plugins.
 * Combines IHD_FieldPlugin declarations with Schema.describeSObject() verification.
 * Only returns fields that are both declared AND exist on the SObject.
 */
public with sharing class IHD_FieldDiscovery {
  private static Map<String, Set<String>> cachedDiscoveredFields;

  /**
   * @description Returns all discovered custom fields for the given SObject.
   * Fields are discovered from enabled IHD_FieldPlugin implementations and
   * verified against Schema.describeSObject().
   * @param sobjectType The SObject API name (e.g., 'Integration_Log__c')
   * @return Set of field API names that are declared and exist on the SObject
   */
  public static Set<String> getDiscoveredFields(String sobjectType) {
    if (cachedDiscoveredFields == null) {
      cachedDiscoveredFields = new Map<String, Set<String>>();
    }
    if (cachedDiscoveredFields.containsKey(sobjectType)) {
      return cachedDiscoveredFields.get(sobjectType);
    }

    Set<String> discoveredFields = new Set<String>();
    Map<String, SObjectField> existingFields = Schema.getGlobalDescribe()
      .get(sobjectType)
      .getDescribe()
      .fields.getMap();

    List<IHD_Plugin__mdt> fieldPlugins = IHD_PluginRegistry.getFieldConfigs();
    for (IHD_Plugin__mdt pluginConfig : fieldPlugins) {
      if (String.isBlank(pluginConfig.DeclaredFields__c)) {
        continue;
      }
      Object pluginInstance = IHD_PluginRegistry.getInstance(pluginConfig);
      if (pluginInstance == null) {
        continue;
      }
      if (pluginInstance instanceof IHD_FieldPlugin) {
        IHD_FieldPlugin fieldPlugin = (IHD_FieldPlugin) pluginInstance;
        for (String fieldName : fieldPlugin.getDeclaredFields()) {
          if (existingFields.containsKey(fieldName.toLowerCase())) {
            discoveredFields.add(fieldName);
          }
        }
      } else {
        for (String fieldName : pluginConfig.DeclaredFields__c.split(',')) {
          String trimmed = fieldName.trim();
          if (
            String.isNotBlank(trimmed) &&
            existingFields.containsKey(trimmed.toLowerCase())
          ) {
            discoveredFields.add(trimmed);
          }
        }
      }
    }

    cachedDiscoveredFields.put(sobjectType, discoveredFields);
    return discoveredFields;
  }

  /**
   * @description Returns a comma-separated list of discovered fields for SOQL.
   * @param sobjectType The SObject API name
   * @return Comma-separated field list (e.g., 'Priority__c,Category__c') or empty string
   */
  public static String getDiscoveredFieldsCsv(String sobjectType) {
    Set<String> fields = getDiscoveredFields(sobjectType);
    if (fields.isEmpty()) {
      return '';
    }
    return String.join(new List<String>(fields), ',');
  }

  /**
   * @description Clears the cached discovered fields. Useful for testing.
   */
  @TestVisible
  private static void clearCache() {
    cachedDiscoveredFields = null;
  }
}
