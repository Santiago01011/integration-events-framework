@IsTest
private class IntegrationHealthControllerTest {

    @TestSetup
    static void setupTestData() {
        List<Integration_Log__c> testLogs = new List<Integration_Log__c>{
            new Integration_Log__c(
                Context__c = 'Pedidos',
                Normalized_Context__c = 'Pedidos',
                Message__c = 'Test message 1',
                PayloadId__c = 'PAYLOAD_001',
                JobId__c = 'JOB_001',
                Processed__c = false,
                ObservationType__c = 'REQUEST_DISPATCHED',
                IntegrationCode__c = 'HTTP-PED',
                CorrelationId__c = 'CORR-001'
            ),
            new Integration_Log__c(
                Context__c = 'Productos',
                Normalized_Context__c = 'Productos',
                Message__c = 'Test message 2',
                PayloadId__c = 'PAYLOAD_002',
                JobId__c = 'JOB_002',
                Processed__c = true,
                ObservationType__c = 'RESPONSE_RECEIVED',
                IntegrationCode__c = 'HTTP-PROD',
                CorrelationId__c = 'CORR-002'
            ),
            new Integration_Log__c(
                Context__c = 'Pedidos_Batch',
                Normalized_Context__c = 'Pedidos',
                Message__c = 'Test message 3',
                PayloadId__c = 'PAYLOAD_003',
                JobId__c = 'JOB_003',
                Processed__c = false,
                ObservationType__c = 'EXCEPTION_THROWN',
                IntegrationCode__c = 'HTTP-PED',
                CorrelationId__c = 'CORR-001'
            )
        };
        insert as system testLogs;
    }

    /**
     * Helper wrapper to call getRecentLogs with an explicit correlationId (null by default)
     */
    private static IntegrationHealthController.IntegrationLogPage callGetRecentLogs(
        Integer pageSize,
        String statusFilter,
        String search,
        Datetime fromDate,
        Datetime toDate,
        Datetime lastCreatedDate,
        Id lastId
    ) {
        return IntegrationHealthController.getRecentLogs(
            pageSize, statusFilter, search, fromDate, toDate, lastCreatedDate, lastId, null
        );
    }

    @IsTest
    static void testGetRecentLogs_Basic() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage page = callGetRecentLogs(
            10, null, null, null, null, null, null
        );

        Test.stopTest();

        System.assertNotEquals(null, page, 'Should return a page object');
        System.assertEquals(3, page.records.size(), 'Should return all three test logs');
        System.assertEquals(10, page.pageSize, 'Page size should be 10');
    }

    @IsTest
    static void testGetRecentLogs_WithStatusFilter() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage unprocessedPage = callGetRecentLogs(
            20, 'Error', null, null, null, null, null
        );

        IntegrationHealthController.IntegrationLogPage processedPage = callGetRecentLogs(
            20, 'Processed', null, null, null, null, null
        );

        Test.stopTest();

        System.assertEquals(2, unprocessedPage.records.size(), 'Should return 2 unprocessed logs');
        System.assertEquals(1, processedPage.records.size(), 'Should return 1 processed log');
    }

    @IsTest
    static void testGetRecentLogs_WithSearch() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage page = callGetRecentLogs(
            20, null, 'PAYLOAD_001', null, null, null, null
        );

        Test.stopTest();

        System.assertEquals(1, page.records.size(), 'Should return one log matching the search');
        System.assertEquals('PAYLOAD_001', page.records[0].PayloadId__c);
    }

    @IsTest
    static void testGetRecentLogs_WithCorrelation() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage page = IntegrationHealthController.getRecentLogs(
            20, null, null, null, null, null, null, 'CORR-001'
        );

        Test.stopTest();

        System.assertEquals(2, page.records.size(), 'Should return logs matching correlation id');
        for (Integration_Log__c log : page.records) {
            System.assertEquals('CORR-001', log.CorrelationId__c);
        }
    }

    @IsTest
    static void testGetRecentLogs_WithDateFilters() {
        Test.startTest();

        Datetime now = Datetime.now();
        Datetime yesterday = now.addDays(-1);
        Datetime tomorrow = now.addDays(1);

        IntegrationHealthController.IntegrationLogPage pageWithinRange = callGetRecentLogs(
            20, null, null, yesterday, tomorrow, null, null
        );

        IntegrationHealthController.IntegrationLogPage pageOutsideRange = callGetRecentLogs(
            20, null, null, tomorrow, tomorrow.addDays(1), null, null
        );

        Test.stopTest();

        System.assertEquals(3, pageWithinRange.records.size(), 'Should return all logs within date range');
        System.assertEquals(0, pageOutsideRange.records.size(), 'Should return no logs outside date range');
    }

    @IsTest
    static void testGetRecentLogs_WithFromDateOnly() {
        Test.startTest();

        Datetime yesterday = Datetime.now().addDays(-1);

        IntegrationHealthController.IntegrationLogPage page = callGetRecentLogs(
            20, null, null, yesterday, null, null, null
        );

        Test.stopTest();

        System.assertEquals(3, page.records.size(), 'Should return all logs created after fromDate');
    }

    @IsTest
    static void testGetRecentLogs_WithToDateOnly() {
        Test.startTest();

        Datetime tomorrow = Datetime.now().addDays(1);

        IntegrationHealthController.IntegrationLogPage page = callGetRecentLogs(
            20, null, null, null, tomorrow, null, null
        );

        Test.stopTest();

        System.assertEquals(3, page.records.size(), 'Should return all logs created before toDate');
    }

    @IsTest
    static void testGetLogDetail() {
        Integration_Log__c testLog = [SELECT Id FROM Integration_Log__c WHERE PayloadId__c = 'PAYLOAD_001' LIMIT 1];
        
        Test.startTest();

        Integration_Log__c logDetail = IntegrationHealthController.getLogDetail(testLog.Id);

        Test.stopTest();

        System.assertNotEquals(null, logDetail, 'Should return log detail');
        System.assertEquals(testLog.Id, logDetail.Id, 'Should return the correct log');
        System.assertEquals('Test message 1', logDetail.Message__c, 'Should include Message field');
        System.assertEquals('PAYLOAD_001', logDetail.PayloadId__c, 'Should include PayloadId field');
        System.assertEquals('JOB_001', logDetail.JobId__c, 'Should include JobId field');
    }

    @IsTest
    static void testGetLogDetail_WithStackTrace() {
        String testStackTrace = 'Class.TestClass.testMethod: line 42\nClass.AnotherClass.method: line 15';
        
        Integration_Log__c logWithStackTrace = new Integration_Log__c(
            Context__c = 'TestContext',
            Normalized_Context__c = 'TestContext',
            Message__c = 'Error with stack trace',
            StackTrace__c = testStackTrace,
            PayloadId__c = 'PAYLOAD_STACK',
            JobId__c = 'JOB_STACK',
            Processed__c = false
        );
        insert as system logWithStackTrace;
        
        Test.startTest();

        Integration_Log__c logDetail = IntegrationHealthController.getLogDetail(logWithStackTrace.Id);

        Test.stopTest();

        System.assertEquals(testStackTrace, logDetail.StackTrace__c, 'Should include heavy StackTrace field');
    }

    @IsTest
    static void testGetRecentLogs_Pagination() {
        Test.startTest();

        IntegrationHealthController.IntegrationLogPage page1 = callGetRecentLogs(
            2, null, null, null, null, null, null
        );

        System.assertEquals(true, page1.hasMore, 'Should indicate more records available');
        System.assertNotEquals(null, page1.nextKey, 'Should provide next key for pagination');

        IntegrationHealthController.IntegrationLogPage page2 = callGetRecentLogs(
            2, null, null, null, null, page1.nextKey.lastCreatedDate, page1.nextKey.lastId
        );

        Test.stopTest();

        System.assertEquals(1, page2.records.size(), 'Second page should have remaining record');
    }

    @IsTest
    static void testSetLogProcessed() {
        Integration_Log__c log = [SELECT Id FROM Integration_Log__c WHERE PayloadId__c = 'PAYLOAD_001' LIMIT 1];
        
        Test.startTest();

        IntegrationHealthController.setLogProcessed(new List<Id>{ log.Id }, true);

        Test.stopTest();

        Integration_Log__c updatedLog = [SELECT Processed__c FROM Integration_Log__c WHERE Id = :log.Id];
        System.assertEquals(true, updatedLog.Processed__c, 'Log should be marked as processed');
    }

    @IsTest
    static void testGetAggregates() {
        Test.startTest();

        IntegrationHealthController.AggregateData agg = IntegrationHealthController.getAggregates();

        Test.stopTest();

        System.assertEquals(2, agg.errorCount, 'Should have 2 unprocessed logs');
        System.assertEquals(1, agg.processedCount, 'Should have 1 processed log');
        System.assertEquals(3, agg.totalCount, 'Total should be 3');
    }

    @IsTest
    static void testGetIntegrationSummaries() {
        Test.startTest();

        List<IntegrationHealthController.IntegrationSummary> summaries = IntegrationHealthController.getIntegrationSummaries();

        Test.stopTest();

        System.assertEquals(2, summaries.size(), 'Should have 2 integration summaries');

        IntegrationHealthController.IntegrationSummary pedidosSummary;
        for (IntegrationHealthController.IntegrationSummary summary : summaries) {
            if (summary.integrationName == 'Pedidos') {
                pedidosSummary = summary;
                break;
            }
        }

        System.assertNotEquals(null, pedidosSummary, 'Should find Pedidos summary');
        System.assertEquals(2, pedidosSummary.totalJobs, 'Pedidos should have 2 total jobs');
        // Test data contains two Pedidos entries which are both unprocessed in the setup.
        // Expect 0 successes, 2 errors, and 0% success rate.
        System.assertEquals(0, pedidosSummary.successCount, 'Should calculate success count');
        System.assertEquals(2, pedidosSummary.errorCount, 'Should calculate error count');
        System.assertEquals(0, pedidosSummary.successPercentage, 'Should calculate success percentage');
    }

    @IsTest
    static void testSecurityWithoutPermission() {
        User testUser = TestDataFactory.createStandardUser('testuser@test.invalid');

        Test.startTest();

        System.runAs(testUser) {
            try {
                callGetRecentLogs(10, null, null, null, null, null, null);
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
                20, null, null, null, null, null, null
            );
            System.assertEquals(3, page.records.size(), 'Should allow access with permission set');
        }

        Test.stopTest();
    }
}
