@IsTest
private class IntegrationEventTriggerTest {
    
    @IsTest
    static void testTriggerCreatesLog() {
        Test.startTest();
        IntegrationEvent__e event = new IntegrationEvent__e(
            Context__c = '{"context":"Test"}',
            ObservationType__c = 'EXCEPTION_THROWN',
            IntegrationCode__c = 'HTTP-LEGACY',
            CorrelationId__c = 'CORR-TRIG',
            ParentEventId__c = 'EVT-PARENT',
            OccurredAt__c = Datetime.now()
        );
        
        Database.SaveResult sr = EventBus.publish(event);
        System.assert(sr.isSuccess());
        
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> logs = [
            SELECT Id, Context__c, ObservationType__c, IntegrationCode__c, CorrelationId__c, ParentEventId__c, OccurredAt__c
            FROM Integration_Log__c
        ];
        
        System.assertEquals(1, logs.size());
        System.assertEquals('{"context":"Test"}', logs[0].Context__c);
        System.assertEquals('EXCEPTION_THROWN', logs[0].ObservationType__c);
        System.assertEquals('HTTP-LEGACY', logs[0].IntegrationCode__c);
        System.assertEquals('CORR-TRIG', logs[0].CorrelationId__c);
        System.assertEquals('EVT-PARENT', logs[0].ParentEventId__c);
        System.assertNotEquals(null, logs[0].OccurredAt__c);
    }
    
    @IsTest
    static void testTriggerMultipleEvents() {
        Test.startTest();
        List<IntegrationEvent__e> events = new List<IntegrationEvent__e>{
            new IntegrationEvent__e(
                Context__c = '{"ctx":"Test1"}',
                ObservationType__c = 'REQUEST_DISPATCHED',
                IntegrationCode__c = 'INT-1',
                CorrelationId__c = 'C-1',
                OccurredAt__c = Datetime.now()
            ),
            new IntegrationEvent__e(
                Context__c = '{"ctx":"Test2"}',
                ObservationType__c = 'RESPONSE_RECEIVED',
                IntegrationCode__c = 'INT-2',
                CorrelationId__c = 'C-2',
                OccurredAt__c = Datetime.now()
            )
        };
        
        List<Database.SaveResult> results = EventBus.publish(events);
        System.assertEquals(2, results.size());
        
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> logs = [SELECT Id FROM Integration_Log__c];
        System.assertEquals(2, logs.size());
    }
}
