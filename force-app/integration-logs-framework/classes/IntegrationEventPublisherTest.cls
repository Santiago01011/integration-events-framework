@IsTest
private class IntegrationEventPublisherTest {
    
    @IsTest
    static void testPublishErrorFull() {
        Test.startTest();
        IntegrationEventPublisher.publishError(
            'TestClass.testMethod',
            'Test error message',
            'Test stack trace',
            'PAYLOAD123',
            'JOB456'
        );
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> logs = [SELECT Id, Context__c, Message__c, PayloadId__c, JobId__c FROM Integration_Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('TestClass.testMethod', logs[0].Context__c);
        System.assertEquals('Test error message', logs[0].Message__c);
        System.assertEquals('PAYLOAD123', logs[0].PayloadId__c);
        System.assertEquals('JOB456', logs[0].JobId__c);
    }

        @IsTest
    static void testPublishErrorMinimal() {
        Test.startTest();
        IntegrationEventPublisher.publishError(
            'TestClass.testMethod',
            'Test error message'
        );
        Test.getEventBus().deliver();
        Test.stopTest();
        List<Integration_Log__c> logs = [SELECT Id, Context__c, Message__c FROM Integration_Log__c LIMIT 1];
        System.assertEquals('TestClass.testMethod', logs[0].Context__c);
        System.assertEquals('Test error message', logs[0].Message__c);
    }
    
    @IsTest
    static void testPublishErrorFromException() {
        Test.startTest();
        try {
            Integer i = 1 / 0;
        } catch (Exception ex) {
            IntegrationEventPublisher.publishError('TestClass.testMethod', ex, 'PAYLOAD789');
        }
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> logs = [SELECT Id, Context__c, Message__c FROM Integration_Log__c];
        System.assertEquals(1, logs.size());
        System.assert(logs[0].Message__c.contains('Divide by 0'));
    }
    
    @IsTest
    static void testPublishErrorFromExceptionWithJobId() {
        Test.startTest();
        try {
            throw new CalloutException('Test callout error');
        } catch (Exception ex) {
            IntegrationEventPublisher.publishError('TestClass.testMethod', ex, 'PAYLOADABC', 'JOBXYZ');
        }
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> logs = [SELECT Id, JobId__c FROM Integration_Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('JOBXYZ', logs[0].JobId__c);
    }

    @IsTest
    static void testPublishInfo() {
        Test.startTest();
        IntegrationEventPublisher.publishInfo('TestClass.testMethod', 'Informational message', 'PAYLOADINFO', 'JOBINFO');
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> logs = [SELECT Id, Context__c, Message__c, PayloadId__c, JobId__c FROM Integration_Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals('TestClass.testMethod', logs[0].Context__c);
        System.assertEquals('Informational message', logs[0].Message__c);
        System.assertEquals('PAYLOADINFO', logs[0].PayloadId__c);
        System.assertEquals('JOBINFO', logs[0].JobId__c);
    }

    @IsTest
    static void testFieldTruncation() {
        String longMessage = 'A'.repeat(35000);
        String longPayloadId = 'C'.repeat(150);
        String longJobId = 'D'.repeat(100);
        
        Test.startTest();
        IntegrationEventPublisher.publishInfo(
            'TestClass.testMethod',
            longMessage,
            longPayloadId,
            longJobId
        );
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> logs = [SELECT Id, Message__c, PayloadId__c, JobId__c FROM Integration_Log__c];
        System.assertEquals(1, logs.size());
        System.assertEquals(32000, logs[0].Message__c.length());
        System.assertEquals(100, logs[0].PayloadId__c.length());
        System.assertEquals(50, logs[0].JobId__c.length());
    }
}