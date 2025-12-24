@IsTest
private class IntegrationEventPublisherTest {
    @IsTest
    static void testEmitPublishesCanonicalFields() {
        Test.startTest();
        IntegrationEventPublisher.emit('HTTP-ORDERS', 'REQUEST_DISPATCHED', 'CORR-1', 'EVT-1', '{"key":"value"}');
        Test.getEventBus().deliver();
        Test.stopTest();

        List<Integration_Log__c> logs = [
            SELECT IntegrationCode__c, ObservationType__c, CorrelationId__c, ParentEventId__c, Context__c, OccurredAt__c
            FROM Integration_Log__c
            ORDER BY OccurredAt__c DESC
            LIMIT 1
        ];

        System.assertEquals('HTTP-ORDERS', logs[0].IntegrationCode__c);
        System.assertEquals('REQUEST_DISPATCHED', logs[0].ObservationType__c);
        System.assertEquals('CORR-1', logs[0].CorrelationId__c);
        System.assertEquals('EVT-1', logs[0].ParentEventId__c);
        System.assertEquals('{"key":"value"}', logs[0].Context__c);
        System.assertNotEquals(null, logs[0].OccurredAt__c);
    }

    @IsTest
    static void testContextTruncation() {
        String longContext = 'A'.repeat(40000);

        Test.startTest();
        IntegrationEventPublisher.emit('HTTP-ORDERS', 'REQUEST_DISPATCHED', 'CORR-2', null, longContext);
        Test.getEventBus().deliver();
        Test.stopTest();

        Integration_Log__c log = [
            SELECT Context__c FROM Integration_Log__c
            ORDER BY OccurredAt__c DESC
            LIMIT 1
        ];

        System.assertEquals(32768, log.Context__c.length());
    }
}