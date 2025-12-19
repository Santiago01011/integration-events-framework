@IsTest
private class IntegrationEventTriggerTest {
    
    @IsTest
    static void testTriggerCreatesLog() {
        Test.startTest();
        IntegrationEvent__e event = new IntegrationEvent__e(
            Context__c = 'TestClass.testMethod',
            EventMessage__c = 'Test error from trigger',
            StackTrace__c = 'Stack trace here',
            PayloadId__c = 'PAYLOAD123',
            JobId__c = 'JOB456',
            Source__c = 'SAP B1'
        );
        
        Database.SaveResult sr = EventBus.publish(event);
        System.assert(sr.isSuccess());
        
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> logs = [
            SELECT Id, Source__c, Context__c, Message__c, StackTrace__c, PayloadId__c, JobId__c, Processed__c 
            FROM Integration_Log__c
        ];
        
        System.assertEquals(1, logs.size());
        System.assertEquals('SAP B1', logs[0].Source__c);
        System.assertEquals('TestClass.testMethod', logs[0].Context__c);
        System.assertEquals('Test error from trigger', logs[0].Message__c);
        System.assertEquals('PAYLOAD123', logs[0].PayloadId__c);
        System.assertEquals('JOB456', logs[0].JobId__c);
        System.assertEquals(false, logs[0].Processed__c);
    }
    
    @IsTest
    static void testTriggerMultipleEvents() {
        Test.startTest();
        List<IntegrationEvent__e> events = new List<IntegrationEvent__e>{
            new IntegrationEvent__e(
                Context__c = 'Test1',
                EventMessage__c = 'Error 1'
            ),
            new IntegrationEvent__e(
                Context__c = 'Test2',
                EventMessage__c = 'Error 2'
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
