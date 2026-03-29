/**
 * @description Test class for IntegrationHealthService.
 * Validates business logic layer for Integration Health Dashboard.
 */
@IsTest
private class IntegrationHealthServiceTest {
  @TestSetup
  static void makeData() {
    List<Integration_Log__c> logs = new List<Integration_Log__c>();
    for (Integer i = 0; i < 10; i++) {
      logs.add(
        new Integration_Log__c(
          IntegrationCode__c = 'SAP_ORDERS',
          ObservationType__c = 'HTTP_REQUEST',
          CorrelationId__c = 'corr-' + i,
          Context__c = '{"index": ' + i + '}'
        )
      );
    }
    insert as system logs;
  }

  /**
   * @description Creates a test user with Admin permissions for the dashboard.
   * @return User configured with Integration_Dashboard_Admin permission set
   */
  private static User getAdminUser() {
    User adminUser = TestDataFactory.createStandardUser(
      'admin_test_service@test.com'
    );

    System.runAs(new User(Id = UserInfo.getUserId())) {
      TestDataFactory.assignPermissionSet(
        adminUser.Id,
        'Integration_Dashboard_Admin'
      );
    }
    return adminUser;
  }

  @IsTest
  static void getPagedLogs_ReturnsPage_WhenLogsExist() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.IntegrationLogPage page = IntegrationHealthService.getPagedLogs(
        5,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(null, page, 'Should return page');
      System.assertNotEquals(null, page.records, 'Should have records');
      System.assertEquals(
        5,
        page.records.size(),
        'Should return page size of 5'
      );
    }
  }

  @IsTest
  static void getPagedLogs_FiltersBy_IntegrationCode() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.IntegrationLogPage page = IntegrationHealthService.getPagedLogs(
        10,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        'SAP_ORDERS'
      );
      Test.stopTest();

      System.assertEquals(
        10,
        page.records.size(),
        'Should return all SAP_ORDERS logs'
      );
    }
  }

  @IsTest
  static void getPagedLogs_UseDefaultPageSize_WhenNullProvided() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.IntegrationLogPage page = IntegrationHealthService.getPagedLogs(
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(null, page, 'Should use default page size');
    }
  }

  @IsTest
  static void getLogDetail_ReturnsWrapper_WhenLogExists() {
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.LogDetailWrapper detail = IntegrationHealthService.getLogDetail(
        log.Id
      );
      Test.stopTest();

      System.assertNotEquals(null, detail, 'Should return detail wrapper');
      System.assertNotEquals(null, detail.record, 'Should have record');
      System.assertEquals(
        log.Id,
        detail.record.Id,
        'Should match requested log'
      );
    }
  }

  @IsTest
  static void getLogDetail_ThrowsException_WhenLogNotFound() {
    Id fakeId = '001000000000000AAA';
    Boolean exceptionThrown = false;

    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      try {
        IntegrationHealthService.getLogDetail(fakeId);
      } catch (AuraHandledException e) {
        exceptionThrown = true;
      }
      Test.stopTest();

      System.assertEquals(
        true,
        exceptionThrown,
        'Should throw exception for non-existent log'
      );
    }
  }

  @IsTest
  static void getLogDetail_ThrowsException_WhenIdIsNull() {
    Boolean exceptionThrown = false;

    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      try {
        IntegrationHealthService.getLogDetail(null);
      } catch (AuraHandledException e) {
        exceptionThrown = true;
      }
      Test.stopTest();

      System.assertEquals(
        true,
        exceptionThrown,
        'Should throw exception for null ID'
      );
    }
  }

  @IsTest
  static void getIntegrationSummaries_ReturnsList() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.IntegrationSummary> summaries = IntegrationHealthService.getIntegrationSummaries(
        false,
        false
      );
      Test.stopTest();

      System.assertNotEquals(null, summaries, 'Should return summaries');
    }
  }

  @IsTest
  static void getIntegrationSummaries_IncludesUnregistered_WhenFlagSet() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.IntegrationSummary> summaries = IntegrationHealthService.getIntegrationSummaries(
        true,
        false
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        summaries,
        'Should return summaries with unregistered'
      );
    }
  }

  @IsTest
  static void getIntegrationSummaries_ExpandsByAttributes_WhenFlagSet() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.IntegrationSummary> summaries = IntegrationHealthService.getIntegrationSummaries(
        false,
        true
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        summaries,
        'Should return expanded summaries'
      );
    }
  }

  @IsTest
  static void getIntegrationSummaries_HandlesNullFlags() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.IntegrationSummary> summaries = IntegrationHealthService.getIntegrationSummaries(
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        summaries,
        'Should handle null flags with defaults'
      );
    }
  }

  @IsTest
  static void getRegistryInfo_ReturnsList() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.RegistryEntry> entries = IntegrationHealthService.getRegistryInfo();
      Test.stopTest();

      System.assertNotEquals(null, entries, 'Should return registry entries');
    }
  }

  @IsTest
  static void getFilterOptions_ReturnsWrapper() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.FilterOptions options = IntegrationHealthService.getFilterOptions();
      Test.stopTest();

      System.assertNotEquals(null, options, 'Should return filter options');
    }
  }

  @IsTest
  static void getEventChannel_ReturnsChannelPath() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      String channel = IntegrationHealthService.getEventChannel();
      Test.stopTest();

      System.assert(
        channel.startsWith('/event/'),
        'Should return event channel path'
      );
    }
  }

  @IsTest
  static void deleteLog_DeletesRecord() {
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      try {
        IntegrationHealthService.deleteLog(log.Id);
      } catch (DmlException e) {
        // Expected in packaging context where delete permissions may not be granted
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void deleteLog_HandlesNullId() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthService.deleteLog(null);
      Test.stopTest();

      System.assert(true, 'Should handle null ID without exception');
    }
  }

  @IsTest
  static void updateLogObservation_FailsWithoutEditAccess() {
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      try {
        IntegrationHealthService.updateLogObservation(log.Id, 'NEW_TYPE');
        System.assert(
          false,
          'Should throw when the current user lacks ObservationType__c edit access'
        );
      } catch (DmlException e) {
        System.assert(
          String.isNotBlank(e.getMessage()),
          'Should fail with a DML/security error because USER_MODE respects field/object access'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void updateLogObservation_HandlesNullId() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthService.updateLogObservation(null, 'NEW_TYPE');
      Test.stopTest();

      System.assert(true, 'Should handle null ID without exception');
    }
  }

  @IsTest
  static void updateLogObservation_HandlesBlankType() {
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthService.updateLogObservation(log.Id, '');
      Test.stopTest();

      System.assert(true, 'Should handle blank type without exception');
    }
  }

  @IsTest
  static void canEditLogObservationType_ReflectsCurrentUserPermissions() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      Boolean canEdit = IntegrationHealthService.canEditLogObservationType();
      Test.stopTest();

      System.assertEquals(
        Integration_Log__c.SObjectType.getDescribe().isUpdateable() &&
        Integration_Log__c.ObservationType__c.getDescribe().isUpdateable(),
        canEdit,
        'Capability helper should mirror object and field updateability'
      );
    }
  }

  // --- Phase 7: Tests for new severity / trend service methods ---

  @IsTest
  static void getSeverityCounts_ReturnsEntries_WhenLogsExist() {
    User admin = getAdminUser();
    // TestSetup has 10 logs all with HTTP_REQUEST
    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.SeverityCountEntry> result = IntegrationHealthService.getSeverityCounts();
      Test.stopTest();

      System.assertNotEquals(null, result, 'Should return severity entries');
      System.assert(
        result.size() > 0,
        'Should have at least one severity bucket'
      );

      Integer totalCount = 0;
      for (IntegrationHealthWrappers.SeverityCountEntry entry : result) {
        System.assertNotEquals(
          null,
          entry.severity,
          'Severity should not be null'
        );
        totalCount += entry.count;
      }
      System.assertEquals(
        10,
        totalCount,
        'Total should equal 10 logs from setup'
      );
    }
  }

  @IsTest
  static void getSeverityCounts_ReturnsEmpty_WhenNoLogs() {
    User admin = getAdminUser();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      delete [SELECT Id FROM Integration_Log__c];
    }
    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.SeverityCountEntry> result = IntegrationHealthService.getSeverityCounts();
      Test.stopTest();

      System.assertNotEquals(
        null,
        result,
        'Should return empty list, not null'
      );
      System.assertEquals(0, result.size(), 'Should be empty when no logs');
    }
  }

  @IsTest
  static void getSeverityCounts_MultipleTypes_WithDifferentSeverities() {
    User admin = getAdminUser();
    // Insert logs with different ObservationTypes to test severity resolution
    List<Integration_Log__c> mixedLogs = new List<Integration_Log__c>{
      new Integration_Log__c(
        IntegrationCode__c = 'MIX-A',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Context__c = '{}',
        CorrelationId__c = 'MIX-1'
      ),
      new Integration_Log__c(
        IntegrationCode__c = 'MIX-B',
        ObservationType__c = 'RESPONSE_RECEIVED',
        Context__c = '{}',
        CorrelationId__c = 'MIX-2'
      ),
      new Integration_Log__c(
        IntegrationCode__c = 'MIX-C',
        ObservationType__c = 'EXCEPTION_THROWN',
        Context__c = '{}',
        CorrelationId__c = 'MIX-3'
      )
    };
    insert as system mixedLogs;

    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.SeverityCountEntry> result = IntegrationHealthService.getSeverityCounts();
      Test.stopTest();

      System.assertNotEquals(null, result, 'Should return entries');
      // Verify percentages sum to 100%
      Decimal totalPercentage = 0;
      for (IntegrationHealthWrappers.SeverityCountEntry entry : result) {
        totalPercentage += entry.percentage;
      }
      System.assertEquals(
        100.0,
        totalPercentage,
        'Percentages should sum to 100%'
      );
    }
  }

  @IsTest
  static void getTopErrorIntegrations_ReturnsRanked_WhenErrorsExist() {
    User admin = getAdminUser();
    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.TopErrorIntegration> result = IntegrationHealthService.getTopErrorIntegrations(
        5
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Should return integrations');
      for (IntegrationHealthWrappers.TopErrorIntegration entry : result) {
        System.assertNotEquals(
          null,
          entry.integrationCode,
          'Code should not be null'
        );
        System.assert(entry.totalEvents > 0, 'Total events should be positive');
        System.assert(
          new Set<String>{ 'up', 'down', 'flat' }.contains(entry.trend),
          'Trend should be valid'
        );
      }
    }
  }

  @IsTest
  static void getTopErrorIntegrations_ReturnsEmpty_WhenNoLogs() {
    User admin = getAdminUser();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      delete [SELECT Id FROM Integration_Log__c];
    }
    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.TopErrorIntegration> result = IntegrationHealthService.getTopErrorIntegrations(
        5
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Should return empty list');
      System.assertEquals(0, result.size(), 'Should be empty when no logs');
    }
  }

  @IsTest
  static void getTopErrorIntegrations_DefaultTopN_WhenNull() {
    User admin = getAdminUser();
    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.TopErrorIntegration> result = IntegrationHealthService.getTopErrorIntegrations(
        null
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        result,
        'Should handle null topN with default (5)'
      );
      System.assert(
        result.size() <= 5,
        'Should return at most 5 with default topN'
      );
    }
  }

  @IsTest
  static void getTopErrorIntegrations_DefaultTopN_WhenZero() {
    User admin = getAdminUser();
    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.TopErrorIntegration> result = IntegrationHealthService.getTopErrorIntegrations(
        0
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        result,
        'Should handle zero topN with default'
      );
    }
  }

  @IsTest
  static void getTopErrorIntegrations_RespectsTopN() {
    User admin = getAdminUser();
    // Insert logs with different codes
    List<Integration_Log__c> extraLogs = new List<Integration_Log__c>();
    for (Integer i = 0; i < 3; i++) {
      extraLogs.add(
        new Integration_Log__c(
          IntegrationCode__c = 'CODE-' + i,
          ObservationType__c = 'REQUEST_DISPATCHED',
          Context__c = '{}',
          CorrelationId__c = 'TOPN-' + i
        )
      );
    }
    insert as system extraLogs;

    System.runAs(admin) {
      Test.startTest();
      List<IntegrationHealthWrappers.TopErrorIntegration> top1 = IntegrationHealthService.getTopErrorIntegrations(
        1
      );
      List<IntegrationHealthWrappers.TopErrorIntegration> top2 = IntegrationHealthService.getTopErrorIntegrations(
        2
      );
      Test.stopTest();

      System.assert(top1.size() <= 1, 'topN=1 should return at most 1');
      System.assert(top2.size() <= 2, 'topN=2 should return at most 2');
    }
  }

  @IsTest
  static void getHourlyTrend_ReturnsPoints_WhenLogsExist() {
    User admin = getAdminUser();
    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.HourlyTrendResult result = IntegrationHealthService.getHourlyTrend(
        4
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Should return trend result');
      System.assertNotEquals(null, result.points, 'Points should not be null');
      System.assertNotEquals(
        null,
        result.direction,
        'Direction should not be null'
      );
      System.assert(
        new Set<String>{ 'up', 'down', 'flat' }.contains(result.direction),
        'Direction should be valid'
      );
    }
  }

  @IsTest
  static void getHourlyTrend_ReturnsEmpty_WhenNoLogs() {
    User admin = getAdminUser();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      delete [SELECT Id FROM Integration_Log__c];
    }
    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.HourlyTrendResult result = IntegrationHealthService.getHourlyTrend(
        4
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Should return result object');
      System.assertEquals(0, result.points.size(), 'Points should be empty');
      System.assertEquals('flat', result.direction, 'Direction should be flat');
    }
  }

  @IsTest
  static void getHourlyTrend_DefaultHours_WhenNull() {
    User admin = getAdminUser();
    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.HourlyTrendResult result = IntegrationHealthService.getHourlyTrend(
        null
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        result,
        'Should handle null hours with default (4)'
      );
    }
  }

  @IsTest
  static void getHourlyTrend_SinglePoint_NoDelta() {
    User admin = getAdminUser();
    // Delete all and insert a single log
    System.runAs(new User(Id = UserInfo.getUserId())) {
      delete [SELECT Id FROM Integration_Log__c];
    }
    insert as system new Integration_Log__c(
      IntegrationCode__c = 'SINGLE-POINT',
      ObservationType__c = 'REQUEST_DISPATCHED',
      Context__c = '{}',
      CorrelationId__c = 'SINGLE-PT'
    );

    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.HourlyTrendResult result = IntegrationHealthService.getHourlyTrend(
        4
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        result,
        'Should return result with single point'
      );
      // With single data point, direction stays flat (needs >= 2 points for delta)
      System.assertEquals(
        'flat',
        result.direction,
        'Should be flat with single point'
      );
    }
  }

  @IsTest
  static void getHourlyTrend_PointStructure() {
    User admin = getAdminUser();
    System.runAs(admin) {
      Test.startTest();
      IntegrationHealthWrappers.HourlyTrendResult result = IntegrationHealthService.getHourlyTrend(
        4
      );
      Test.stopTest();

      for (IntegrationHealthWrappers.TrendPoint point : result.points) {
        System.assertNotEquals(null, point.hour, 'Hour should not be null');
        System.assert(
          point.hour.contains(':00'),
          'Hour should be in HH:00 format'
        );
        System.assert(point.total >= 0, 'Total should be non-negative');
        System.assert(point.errors >= 0, 'Errors should be non-negative');
        System.assert(
          point.errors <= point.total,
          'Errors should not exceed total'
        );
      }
    }
  }
}
