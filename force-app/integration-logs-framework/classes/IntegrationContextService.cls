/**
 * @description Service for normalizing integration context names using Custom Metadata.
 * The normalization helps in categorizing and filtering integration logs effectively, but is not mandatory.
 * To use this service, check the documentation and set up the Custom Metadata Type with desired mappings.
 * If no mapping is found, the original context name is returned and used for the charts.
 * This service uses SYSTEM_MODE to ensure CMDT is readable from trigger contexts.
 */
public with sharing class IntegrationContextService {
  private static Map<String, String> contextMappings;

 /**
  * @description Sets test context mappings for unit test isolation.
  * @param testMap Map of keyword to normalized context for testing
  */
  @TestVisible
  private static void setTestContextMappings(Map<String, String> testMap) {
    contextMappings = testMap;
  }

  /**
   * @description Loads the CMDT mappings into a static map for performance.
   * Must run WITH SYSTEM_MODE to be readable from a trigger.
   */
  private static void initializeContextMappings() {
    if (contextMappings == null) {
      contextMappings = new Map<String, String>();
      for (Integration_Context_Mapping__mdt mapping : [
        SELECT Context_Keyword__c, Normalized_Context__c
        FROM Integration_Context_Mapping__mdt
        WITH SYSTEM_MODE
      ]) {
        if (String.isNotBlank(mapping.Context_Keyword__c)) {
          contextMappings.put(mapping.Context_Keyword__c.toLowerCase(), mapping.Normalized_Context__c);
        }
      }
    }
  }

  /**
   * @description Dynamically normalizes a context name using Custom Metadata.
   * @param context The raw context value (e.g., "SObjectbatch")
   * @return The normalized base context name (e.g., "Sobject") or "SObjectbatch" if no match found.
   */
  public static String normalize(String context) {
    if (String.isBlank(context)) {
      return 'Debug';
    }

    initializeContextMappings();

    String normalizedInput = context.trim().toLowerCase();

    for (String keyword : contextMappings.keySet()) {
      if (normalizedInput.contains(keyword)) {
        return contextMappings.get(keyword);
      }
    }
    return context.trim();
  }
}