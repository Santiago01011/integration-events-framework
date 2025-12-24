@IsTest
private class IntegrationHealthControllerTest {

    @TestSetup
    static void setupTestData() {
        Datetime now = Datetime.now();
        List<Integration_Log__c> testLogs = new List<Integration_Log__c>{
            new Integration_Log__c(
                Context__c = '{"ctx":"Pedidos"}',
                Normalized_Context__c = 'Pedidos',
                ObservationType__c = 'REQUEST_DISPATCHED',
                IntegrationCode__c = 'HTTP-PED',
                CorrelationId__c = 'CORR-001',
                OccurredAt__c = now.addMinutes(-5)
            ),
            new Integration_Log__c(
                Context__c = '{"ctx":"Productos"}',
                Normalized_Context__c = 'Productos',
                ObservationType__c = 'RESPONSE_RECEIVED',
                IntegrationCode__c = 'HTTP-PROD',
                CorrelationId__c = 'CORR-002',
                OccurredAt__c = now.addMinutes(-3)
            ),
            new Integration_Log__c(
                Context__c = '{"ctx":"Pedidos_Batch"}',
                Normalized_Context__c = 'Pedidos',
                ObservationType__c = 'EXCEPTION_THROWN',
                IntegrationCode__c = 'HTTP-PED',
                CorrelationId__c = 'CORR-001',
                OccurredAt__c = now.addMinutes(-1)
            )
        };
        insert as system testLogs;
    }

    private static IntegrationHealthController.IntegrationLogPage callGetRecentLogs(
        Integer pageSize,
        String search,
        String fromOccurredAt,
        String toOccurredAt,
        Datetime lastOccurredAt,
        Id lastId,
        String correlationId,
        String observationType,
        String integrationCode
    ) {
        return IntegrationHealthController.getRecentLogs(
            pageSize,
            search,
            fromOccurredAt,
            toOccurredAt,
            lastOccurredAt,
            lastId,
            correlationId,
            observationType,
            integrationCode
        );
    }

    @IsTest
    static void testGetLogDetails() {
        Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];
        
        Test.startTest();
        IntegrationHealthController.LogDetailWrapper details = IntegrationHealthController.getLogDetail(log.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, details, 'Should return log details');
        System.assertEquals(log.Id, details.record.Id, 'Should return the correct log');
        System.assertNotEquals(null, details.record.Context__c, 'Should return the context field');
    }

    @IsTest
    static void testGetRecentLogs_Basic() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage page = callGetRecentLogs(
            10, null, null, null, null, null, null, null, null
        );

        Test.stopTest();

        System.assertNotEquals(null, page, 'Should return a page object');
        System.assertEquals(3, page.records.size(), 'Should return all three test logs');
        System.assertEquals(10, page.pageSize, 'Page size should be 10');
    }

    @IsTest
    static void testGetRecentLogs_WithSearch() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage page = callGetRecentLogs(
            20, 'Productos', null, null, null, null, null, null, null
        );

        Test.stopTest();

        System.assertEquals(1, page.records.size(), 'Should return one log matching the search');
        System.assertEquals('HTTP-PROD', page.records[0].IntegrationCode__c);
    }

    @IsTest
    static void testGetRecentLogs_WithCorrelation() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage page = callGetRecentLogs(
            20, null, null, null, null, null, 'CORR-001', null, null
        );

        Test.stopTest();

        System.assertEquals(2, page.records.size(), 'Should return logs matching correlation id');
        for (Integration_Log__c log : page.records) {
            System.assertEquals('CORR-001', log.CorrelationId__c);
        }
    }

    @IsTest
    static void testGetRecentLogs_WithObservationAndIntegration() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage page = callGetRecentLogs(
            20, null, null, null, null, null, null, 'EXCEPTION_THROWN', 'HTTP-PED'
        );

        Test.stopTest();

        System.assertEquals(1, page.records.size(), 'Should return matching observation and integration');
        System.assertEquals('EXCEPTION_THROWN', page.records[0].ObservationType__c);
    }

    @IsTest
    static void testGetRecentLogs_WithDateFilters() {
        Datetime now = Datetime.now();
        Datetime earlier = now.addMinutes(-10);
        Datetime later = now.addMinutes(10);

        Test.startTest();

        IntegrationHealthController.IntegrationLogPage pageWithinRange = callGetRecentLogs(
            20, null, earlier.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''), later.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''), null, null, null, null, null
        );

        IntegrationHealthController.IntegrationLogPage pageOutsideRange = callGetRecentLogs(
            20, null, later.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''), later.addMinutes(5).format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''), null, null, null, null, null
        );

        Test.stopTest();

        System.assertEquals(3, pageWithinRange.records.size(), 'Should return all logs within date range');
        System.assertEquals(0, pageOutsideRange.records.size(), 'Should return no logs outside date range');
    }

    @IsTest
    static void testGetRecentLogs_Pagination() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage page1 = callGetRecentLogs(
            2, null, null, null, null, null, null, null, null
        );

        System.assertEquals(true, page1.hasMore, 'Should indicate more records available');
        System.assertNotEquals(null, page1.nextKey, 'Should provide next key for pagination');

        IntegrationHealthController.IntegrationLogPage page2 = callGetRecentLogs(
            2, null, null, null, page1.nextKey.lastOccurredAt, page1.nextKey.lastId, null, null, null
        );

        Test.stopTest();

        System.assertEquals(1, page2.records.size(), 'Second page should have remaining record');
    }

    @IsTest
    static void testGetLogDetail() {
        Integration_Log__c testLog = [SELECT Id FROM Integration_Log__c WHERE IntegrationCode__c = 'HTTP-PED' LIMIT 1];
        
        Test.startTest();

        IntegrationHealthController.LogDetailWrapper logDetail = IntegrationHealthController.getLogDetail(testLog.Id);

        Test.stopTest();

        System.assertNotEquals(null, logDetail, 'Should return log detail');
        System.assertEquals(testLog.Id, logDetail.record.Id, 'Should return the correct log');
        System.assertEquals('HTTP-PED', logDetail.record.IntegrationCode__c, 'Should include IntegrationCode field');
    }

    @IsTest
    static void testGetIntegrationSummaries() {
        Test.startTest();

        List<IntegrationHealthController.IntegrationSummary> summaries = IntegrationHealthController.getIntegrationSummaries();

        Test.stopTest();

        System.assertEquals(2, summaries.size(), 'Should have 2 integration summaries');

        Boolean foundPed = false;
        Boolean foundProd = false;
        for (IntegrationHealthController.IntegrationSummary summary : summaries) {
            if (summary.integrationCode == 'HTTP-PED') {
                foundPed = true;
                System.assertEquals(2, summary.totalEvents, 'HTTP-PED should have 2 events');
            }
            if (summary.integrationCode == 'HTTP-PROD') {
                foundProd = true;
                System.assertEquals(1, summary.totalEvents, 'HTTP-PROD should have 1 event');
            }
        }

        System.assert(foundPed, 'Should find HTTP-PED summary');
        System.assert(foundProd, 'Should find HTTP-PROD summary');
    }

    @IsTest
    static void testSecurityWithoutPermission() {
        User testUser = TestDataFactory.createStandardUser('testuser@test.invalid');

        Test.startTest();

        System.runAs(testUser) {
            try {
                callGetRecentLogs(10, null, null, null, null, null, null, null, null);
                System.assert(false, 'Should throw security exception');
            } catch (AuraHandledException ex) {
                System.assert(true, 'Correctly prevented access');
            }
        }

        Test.stopTest();
    }

    @IsTest
    static void testSecurityWithPermission() {
        User testUser = TestDataFactory.createStandardUser('testuser2@test.invalid');
        TestDataFactory.assignPermissionSet(testUser.Id, 'Integration_Dashboard_Read');

        Test.startTest();

        System.runAs(testUser) {
            IntegrationHealthController.IntegrationLogPage page = callGetRecentLogs(
                20, null, null, null, null, null, null, null, null
            );
            System.assertEquals(3, page.records.size(), 'Should allow access with permission set');
        }

        Test.stopTest();
    }
}
