/**
 * @description Handler for Integration_Log__c record creation from IntegrationEvent__e platform events.
 * Implements the controller pattern to separate trigger logic from business logic.
 */
public with sharing class IntegrationLogHandler {

    /**
     * @description Handles the 'after insert' logic for IntegrationEvent__e events.
     * Creates Integration_Log__c records with normalized context values.
     * @param newEvents The list of new platform events from Trigger.new
     */
    public static void handleEvents(List<IntegrationEvent__e> newEvents) {
        
        List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();
        
        for (IntegrationEvent__e event : newEvents) {
            
            Integration_Log__c log = new Integration_Log__c(
                Context__c = event.Context__c,
                Message__c = event.EventMessage__c,
                StackTrace__c = event.StackTrace__c,
                PayloadId__c = event.PayloadId__c,
                JobId__c = event.JobId__c,
                Source__c = event.Source__c,
                Processed__c = event.Processed__c
            );

            log.Normalized_Context__c = IntegrationContextService.normalize(event.Context__c);
            
            logsToInsert.add(log);
        }
        
        if (!logsToInsert.isEmpty()) {
            insert as system logsToInsert;
        }
    }
}