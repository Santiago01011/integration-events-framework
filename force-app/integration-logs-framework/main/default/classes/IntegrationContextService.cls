/**
 * @description Service for normalizing integration codes using the Integration Registry.
 *
 * Uses the idhIntegration_Definition__mdt to map integration codes to their
 * configured Group values for dashboard grouping and display.
 *
 * This service uses SYSTEM_MODE to ensure CMDT is readable from trigger contexts.
 */
public with sharing class IntegrationContextService {
  @TestVisible
  private static Map<String, String> registryMappings;

  /**
   * @description Sets test registry mappings for unit test isolation.
   * @param testMap Map of IntegrationCode to Group for testing
   */
  @TestVisible
  private static void setTestContextMappings(Map<String, String> testMap) {
    registryMappings = new Map<String, String>();
    if (testMap != null) {
      for (String key : testMap.keySet()) {
        registryMappings.put(key.toUpperCase(), testMap.get(key));
      }
    }
  }

  @TestVisible
  private static List<idhIntegration_Definition__mdt> mockDefinitions;

  /**
   * @description Loads the Integration Registry into a static map for performance.
   */
  private static void initializeRegistryMappings() {
    if (registryMappings == null) {
      registryMappings = new Map<String, String>();

      List<idhIntegration_Definition__mdt> definitions = (Test.isRunningTest() &&
        mockDefinitions != null)
        ? mockDefinitions
        : [
            SELECT IntegrationCode__c, Group__c, Label__c
            FROM idhIntegration_Definition__mdt
            WHERE Enabled__c = TRUE
            WITH SYSTEM_MODE
          ];

      for (idhIntegration_Definition__mdt def : definitions) {
        if (String.isNotBlank(def.IntegrationCode__c)) {
          String normalized = String.isNotBlank(def.Group__c)
            ? def.Group__c
            : (String.isNotBlank(def.Label__c)
                ? def.Label__c
                : def.IntegrationCode__c);
          registryMappings.put(
            def.IntegrationCode__c.toUpperCase(),
            normalized.trim()
          );
        }
      }
    }
  }

  /**
   * @description Normalizes an integration code using the Registry.
   * @param integrationCode The raw integration code (e.g., "ORDERS_BATCH")
   * @return The normalized group name from the Registry, or the original code if not registered.
   */
  public static String normalize(String integrationCode) {
    if (String.isBlank(integrationCode)) {
      return 'Unregistered';
    }

    initializeRegistryMappings();
    String codeUpper = integrationCode.trim().toUpperCase();

    if (registryMappings.containsKey(codeUpper)) {
      return registryMappings.get(codeUpper);
    }

    return integrationCode.trim();
  }
}
