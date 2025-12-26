@IsTest
private class IntegrationHealthControllerTest {

    @TestSetup
    static void setupTestData() {
        User dashboardUser = TestDataFactory.createStandardUser('dashboard_user@test.com');
        
        System.runAs(new User(Id = UserInfo.getUserId())) {
            TestDataFactory.assignPermissionSet(dashboardUser.Id, 'Integration_Dashboard_Read');
        }

        Datetime now = Datetime.now();
        
        List<Integration_Log__c> logs = new List<Integration_Log__c>{
            new Integration_Log__c(
                IntegrationCode__c = 'HTTP-PED',
                ObservationType__c = 'REQUEST_DISPATCHED',
                Context__c = '{"id": 101}',
                Normalized_Context__c = 'Pedidos',
                CorrelationId__c = 'CORR-001',
                OccurredAt__c = now.addMinutes(-5)
            ),
            new Integration_Log__c(
                IntegrationCode__c = 'HTTP-PROD',
                ObservationType__c = 'RESPONSE_RECEIVED',
                Context__c = '{"sku": "XYZ"}',
                Normalized_Context__c = 'Productos',
                CorrelationId__c = 'CORR-002',
                OccurredAt__c = now.addMinutes(-3)
            ),
            new Integration_Log__c(
                IntegrationCode__c = 'HTTP-PED',
                ObservationType__c = 'EXCEPTION_THROWN',
                Context__c = '{"error": "bad"}',
                Normalized_Context__c = 'Pedidos',
                CorrelationId__c = 'CORR-001',
                OccurredAt__c = now.addMinutes(-1)
            )
        };
        insert logs;
    }

    private static User getDashboardUser() {
        return [SELECT Id FROM User WHERE Username = 'dashboard_user@test.com' LIMIT 1];
    }

    @IsTest
    static void testGetRecentLogs_ReturnsData() {
        User u = getDashboardUser();
        
        System.runAs(u) {
            Test.startTest();
            IntegrationHealthController.IntegrationLogPage result = IntegrationHealthController.getRecentLogs(
                20, null, null, null, null, null, null, null, null
            );
            Test.stopTest();

            System.assertNotEquals(null, result, 'Result object should not be null');
            System.assertEquals(3, result.records.size(), 'Should return all 3 logs created in setup');
            System.assertEquals(false, result.hasMore, 'Should not have more pages');
        }
    }

    @IsTest
    static void testGetRecentLogs_WithSearch() {
        User u = getDashboardUser();
        
        System.runAs(u) {
            Test.startTest();
            IntegrationHealthController.IntegrationLogPage result = IntegrationHealthController.getRecentLogs(
                20, 'Productos', null, null, null, null, null, null, null
            );
            Test.stopTest();

            System.assertEquals(1, result.records.size(), 'Should match 1 record for Productos');
            System.assertEquals('HTTP-PROD', result.records[0].IntegrationCode__c, 'Should be the Product integration');
        }
    }

    @IsTest
    static void testGetRecentLogs_WithDateFilters() {
        User u = getDashboardUser();
        Datetime now = Datetime.now();
        
        String fromDate = JSON.serialize(now.addMinutes(-10)).replace('"', '');
        String toDate = JSON.serialize(now.addMinutes(10)).replace('"', '');
        
        String futureFrom = JSON.serialize(now.addDays(1)).replace('"', '');
        String futureTo = JSON.serialize(now.addDays(2)).replace('"', '');

        System.runAs(u) {
            Test.startTest();
            
            IntegrationHealthController.IntegrationLogPage validRange = IntegrationHealthController.getRecentLogs(
                20, null, fromDate, toDate, null, null, null, null, null
            );
            
            IntegrationHealthController.IntegrationLogPage emptyRange = IntegrationHealthController.getRecentLogs(
                20, null, futureFrom, futureTo, null, null, null, null, null
            );

            Test.stopTest();

            System.assertEquals(3, validRange.records.size(), 'Should return 3 records in the valid -10/+10 min window');
            System.assertEquals(0, emptyRange.records.size(), 'Should return 0 records for future dates');
        }
    }

    @IsTest
    static void testGetRecentLogs_SpecificFilters() {
        User u = getDashboardUser();
        
        System.runAs(u) {
            Test.startTest();
            IntegrationHealthController.IntegrationLogPage corrResult = IntegrationHealthController.getRecentLogs(
                20, null, null, null, null, null, 'CORR-001', null, null
            );
            
            IntegrationHealthController.IntegrationLogPage typeResult = IntegrationHealthController.getRecentLogs(
                20, null, null, null, null, null, null, 'EXCEPTION_THROWN', null
            );
            Test.stopTest();

            System.assertEquals(2, corrResult.records.size(), 'Should find 2 logs with CORR-001');
            System.assertEquals(1, typeResult.records.size(), 'Should find 1 log with EXCEPTION_THROWN');
        }
    }
    @IsTest
    static void testGetIntegrationSummaries() {
        User u = getDashboardUser();

        System.runAs(u) {
            Test.startTest();
            List<IntegrationHealthController.IntegrationSummary> summaries = IntegrationHealthController.getIntegrationSummaries();
            Test.stopTest();

            System.assertNotEquals(null, summaries, 'Summaries should not be null');
            System.assertEquals(2, summaries.size(), 'Should group into 2 integrations');

            Map<String, IntegrationHealthController.IntegrationSummary> summaryMap = new Map<String, IntegrationHealthController.IntegrationSummary>();
            for(IntegrationHealthController.IntegrationSummary s : summaries) {
                summaryMap.put(s.integrationCode, s);
            }

            System.assert(summaryMap.containsKey('Pedidos'), 'Should contain Pedidos (Normalized Context) group');
            System.assertEquals(2, summaryMap.get('Pedidos').totalEvents, 'Pedidos should have 2 events');
            
            // Verify the second group
            System.assert(summaryMap.containsKey('Productos'), 'Should contain Productos group');
            System.assertEquals(1, summaryMap.get('Productos').totalEvents, 'Productos should have 1 event');
        }
    }

    @IsTest
    static void testGetLogDetail_Security() {
        User u = getDashboardUser();
        Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            IntegrationHealthController.LogDetailWrapper result = IntegrationHealthController.getLogDetail(log.Id);
            Test.stopTest();

            System.assertNotEquals(null, result);
            System.assertEquals(log.Id, result.record.Id);
        }
    }

    @IsTest
    static void testSecurityEnforcement() {
        User outsider = TestDataFactory.createStandardUser('outsider@test.com');
        
        System.runAs(outsider) {
            try {
                IntegrationHealthController.getRecentLogs(10, null, null, null, null, null, null, null, null);
                System.assert(false, 'Should have thrown an AuraHandledException due to security');
            } catch (Exception e) {
                System.assert(true);
            }
        }
    }
}
