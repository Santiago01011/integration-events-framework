/**
 * @description Handler for Integration_Log__c record creation from IntegrationEvent__e platform events.
 * Implements the controller pattern to separate trigger logic from business logic.
 */
public without sharing class IntegrationLogHandler {

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
                Normalized_Context__c = IntegrationContextService.normalize(event.IntegrationCode__c),
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
}