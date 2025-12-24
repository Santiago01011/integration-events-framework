/**
 * @description Handler for Integration_Log__c record creation from IntegrationEvent__e platform events.
 * Implements the controller pattern to separate trigger logic from business logic.
 */
public without sharing class IntegrationLogHandler {

    private static Map<String, String> contextKeywordToNormalized;

    /**
     * @description Handles the 'after insert' logic for IntegrationEvent__e events.
     * Creates Integration_Log__c records with normalized context values.
     * @param newEvents The list of new platform events from Trigger.new
     */
    public static void handleEvents(List<IntegrationEvent__e> newEvents) {
        if (newEvents == null || newEvents.isEmpty()) {
            return;
        }

        List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();

        for (IntegrationEvent__e event : newEvents) {
            
            Integration_Log__c log = new Integration_Log__c(
                Context__c = event.Context__c,
                Normalized_Context__c = resolveNormalizedContext(event.IntegrationCode__c),
                ObservationType__c = event.ObservationType__c,
                IntegrationCode__c = event.IntegrationCode__c,
                CorrelationId__c = event.CorrelationId__c,
                ParentEventId__c = event.ParentEventId__c,
                OccurredAt__c = event.OccurredAt__c
            );
            
            logsToInsert.add(log);
        }

        if (!logsToInsert.isEmpty()) {
            insert as system logsToInsert;
        }
    }

    /**
     * @description Normalizes the raw context string based on configurable metadata keywords.
     */
    private static String resolveNormalizedContext(String context) {
        if (String.isBlank(context)) {
            return null;
        }

        ensureContextMappingsLoaded();
        if (contextKeywordToNormalized.isEmpty()) {
            return null;
        }

        String contextLower = context.toLowerCase();
        String mappedValue;
        Integer longestMatchLength = 0;

        for (String keyword : contextKeywordToNormalized.keySet()) {
            if (String.isBlank(keyword)) {
                continue;
            }
            if (contextLower.contains(keyword) && keyword.length() > longestMatchLength) {
                longestMatchLength = keyword.length();
                mappedValue = contextKeywordToNormalized.get(keyword);
            }
        }

        return mappedValue;
    }

    /**
     * @description Lazily loads the context keyword mappings so admins can drive the normalized labels.
     */
    private static void ensureContextMappingsLoaded() {
        if (contextKeywordToNormalized != null) {
            return;
        }

        contextKeywordToNormalized = new Map<String, String>();
        for (Integration_Context_Mapping__mdt mapping : [
            SELECT Context_Keyword__c, Normalized_Context__c
            FROM Integration_Context_Mapping__mdt
            WITH SYSTEM_MODE
        ]) {
            if (String.isBlank(mapping.Context_Keyword__c) || String.isBlank(mapping.Normalized_Context__c)) {
                continue;
            }
            String keyword = mapping.Context_Keyword__c.trim().toLowerCase();
            String normalizedValue = mapping.Normalized_Context__c.trim();
            contextKeywordToNormalized.put(keyword, normalizedValue);
        }
    }
}