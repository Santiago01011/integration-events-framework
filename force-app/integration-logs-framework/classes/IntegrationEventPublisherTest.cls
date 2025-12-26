@IsTest
private class IntegrationEventPublisherTest {
    
    @IsTest
    static void testEmitAndTriggerFlow() {
        String integrationCode = 'TEST-INT-01';
        String observation = 'UNIT_TEST';
        String correlationId = 'UUID-999';
        Map<String, Object> context = new Map<String, Object>{'status' => 'OK'};

        Test.startTest();
        IntegrationEventPublisher.emit(
            integrationCode, 
            observation, 
            correlationId, 
            null, 
            JSON.serialize(context)
        );
        
        Test.getEventBus().deliver();
        Test.stopTest();

        Integration_Log__c storedLog = [
            SELECT IntegrationCode__c, ObservationType__c, CorrelationId__c, Context__c
            FROM Integration_Log__c
            WHERE CorrelationId__c = :correlationId
            LIMIT 1
        ];

        System.assertNotEquals(null, storedLog, 'Log should be persisted to DB');
        System.assertEquals(integrationCode, storedLog.IntegrationCode__c);
        System.assertEquals(observation, storedLog.ObservationType__c);
        System.assert(storedLog.Context__c.contains('OK'), 'Context JSON should contain payload');
    }
}