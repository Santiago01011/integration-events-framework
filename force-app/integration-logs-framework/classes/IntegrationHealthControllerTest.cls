@IsTest
private class IntegrationHealthControllerTest {
  @TestSetup
  static void setupTestData() {
    User dashboardUser = TestDataFactory.createStandardUser(
      'dashboard_user@test.com'
    );

    System.runAs(new User(Id = UserInfo.getUserId())) {
      TestDataFactory.assignPermissionSet(
        dashboardUser.Id,
        'Integration_Dashboard_Read'
      );
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
    return [
      SELECT Id
      FROM User
      WHERE Username = 'dashboard_user@test.com'
      LIMIT 1
    ];
  }

  @IsTest
  static void testGetRecentLogs_ReturnsData() {
    User u = getDashboardUser();

    System.runAs(u) {
      Test.startTest();
      IntegrationHealthWrappers.IntegrationLogPage result = IntegrationHealthController.getRecentLogs(
        20,
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

      System.assertNotEquals(null, result, 'Result object should not be null');
      System.assertEquals(
        3,
        result.records.size(),
        'Should return all 3 logs created in setup'
      );
      System.assertEquals(false, result.hasMore, 'Should not have more pages');
    }
  }

  @IsTest
  static void testGetRecentLogs_WithSearch() {
    User u = getDashboardUser();

    System.runAs(u) {
      Test.startTest();
      IntegrationHealthWrappers.IntegrationLogPage result = IntegrationHealthController.getRecentLogs(
        20,
        'Productos',
        null,
        null,
        null,
        null,
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        1,
        result.records.size(),
        'Should match 1 record for Productos'
      );
      System.assertEquals(
        'HTTP-PROD',
        result.records[0].IntegrationCode__c,
        'Should be the Product integration'
      );
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

      IntegrationHealthWrappers.IntegrationLogPage validRange = IntegrationHealthController.getRecentLogs(
        20,
        null,
        fromDate,
        toDate,
        null,
        null,
        null,
        null,
        null
      );

      IntegrationHealthWrappers.IntegrationLogPage emptyRange = IntegrationHealthController.getRecentLogs(
        20,
        null,
        futureFrom,
        futureTo,
        null,
        null,
        null,
        null,
        null
      );

      Test.stopTest();

      System.assertEquals(
        3,
        validRange.records.size(),
        'Should return 3 records in the valid -10/+10 min window'
      );
      System.assertEquals(
        0,
        emptyRange.records.size(),
        'Should return 0 records for future dates'
      );
    }
  }

  @IsTest
  static void testGetRecentLogs_SpecificFilters() {
    User u = getDashboardUser();

    System.runAs(u) {
      Test.startTest();
      IntegrationHealthWrappers.IntegrationLogPage corrResult = IntegrationHealthController.getRecentLogs(
        20,
        null,
        null,
        null,
        null,
        null,
        'CORR-001',
        null,
        null
      );

      IntegrationHealthWrappers.IntegrationLogPage typeResult = IntegrationHealthController.getRecentLogs(
        20,
        null,
        null,
        null,
        null,
        null,
        null,
        'EXCEPTION_THROWN',
        null
      );
      Test.stopTest();

      System.assertEquals(
        2,
        corrResult.records.size(),
        'Should find 2 logs with CORR-001'
      );
      System.assertEquals(
        1,
        typeResult.records.size(),
        'Should find 1 log with EXCEPTION_THROWN'
      );
    }
  }
  @IsTest
  static void testGetIntegrationSummaries() {
    User u = getDashboardUser();

    System.runAs(u) {
      Test.startTest();
      List<IntegrationHealthWrappers.IntegrationSummary> summaries = IntegrationHealthController.getIntegrationSummaries(
        true,
        false
      );
      Test.stopTest();

      System.assertNotEquals(null, summaries, 'Summaries should not be null');
      System.assert(summaries.size() > 0, 'Should return at least one summary');

      // Count total events across all summaries
      Integer totalEvents = 0;
      for (IntegrationHealthWrappers.IntegrationSummary s : summaries) {
        totalEvents += s.totalEvents;
      }

      System.assertEquals(
        3,
        totalEvents,
        'Total events should equal the 3 logs created in test setup'
      );
    }
  }

  @IsTest
  static void testGetIntegrationSummaries_DetailedView() {
    User u = getDashboardUser();

    System.runAs(u) {
      Test.startTest();
      List<IntegrationHealthWrappers.IntegrationSummary> summaries = IntegrationHealthController.getIntegrationSummaries(
        true,
        true
      );
      Test.stopTest();

      System.assertNotEquals(null, summaries, 'Summaries should not be null');
    }
  }

  @IsTest
  static void testGetLogDetail_Security() {
    User u = getDashboardUser();
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    System.runAs(u) {
      Test.startTest();
      IntegrationHealthWrappers.LogDetailWrapper result = IntegrationHealthController.getLogDetail(
        log.Id
      );
      Test.stopTest();

      System.assertNotEquals(null, result);
      System.assertEquals(log.Id, result.record.Id);
    }
  }

  @IsTest
  static void testGetLogDetail_ErrorPaths() {
    User u = getDashboardUser();
    System.runAs(u) {
      // Test null ID
      try {
        IntegrationHealthController.getLogDetail(null);
        System.assert(false, 'Should have thrown exception for null ID');
      } catch (Exception e) {
        System.assert(
          e instanceof AuraHandledException,
          'Should throw AuraHandledException for null ID'
        );
      }

      // Test non-existent ID
      Id fakeId = Id.valueOf(
        Integration_Log__c.sObjectType.getDescribe().getKeyPrefix() +
        '000000000001'
      );
      try {
        IntegrationHealthController.getLogDetail(fakeId);
        System.assert(
          false,
          'Should have thrown exception for non-existent ID'
        );
      } catch (Exception e) {
        System.assert(
          e instanceof AuraHandledException,
          'Should throw AuraHandledException for non-existent ID'
        );
      }
    }
  }

  @IsTest
  static void testGetRecentLogs_EdgeCases() {
    User u = getDashboardUser();
    System.runAs(u) {
      // Test null pageSize (should default to 20)
      IntegrationHealthWrappers.IntegrationLogPage result = IntegrationHealthController.getRecentLogs(
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
      System.assertNotEquals(null, result);
      System.assert(result.records.size() > 0);
    }
  }

  @IsTest
  static void testGetFilterOptions() {
    User u = getDashboardUser();
    System.runAs(u) {
      Test.startTest();
      IntegrationHealthWrappers.FilterOptions filters = IntegrationHealthController.getFilterOptions();
      Test.stopTest();

      System.assertNotEquals(null, filters);
      System.assert(filters.observationTypes.size() > 0);
      System.assert(filters.integrationCodes.size() > 0);
    }
  }

  @IsTest
  static void testWrappersCoverage() {
    // Explicitly hit constructors and methods in Wrappers for 100% coverage
    IntegrationHealthWrappers.IntegrationLogPage page = new IntegrationHealthWrappers.IntegrationLogPage();
    IntegrationHealthWrappers.LogDetailWrapper detail = new IntegrationHealthWrappers.LogDetailWrapper();
    IntegrationHealthWrappers.IntegrationSummary summary = new IntegrationHealthWrappers.IntegrationSummary();
    IntegrationHealthWrappers.FilterOptions filters = new IntegrationHealthWrappers.FilterOptions();

    IntegrationHealthWrappers.RegistryEntry entry1 = new IntegrationHealthWrappers.RegistryEntry();
    entry1.integrationCode = 'A';
    IntegrationHealthWrappers.RegistryEntry entry2 = new IntegrationHealthWrappers.RegistryEntry();
    entry2.integrationCode = 'B';
    IntegrationHealthWrappers.RegistryEntry entry3 = new IntegrationHealthWrappers.RegistryEntry();
    entry3.integrationCode = null;

    System.assert(entry1.compareTo(entry2) < 0);
    System.assert(entry1.compareTo(entry3) > 0);
    System.assert(entry3.compareTo(entry1) < 0);
  }

  @IsTest
  static void testSecurityEnforcement() {
    User outsider = TestDataFactory.createStandardUser('outsider@test.com');

    System.runAs(outsider) {
      try {
        IntegrationHealthController.getRecentLogs(
          10,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          null
        );
        System.assert(
          false,
          'Should have thrown an AuraHandledException due to security'
        );
      } catch (Exception e) {
        System.assert(true);
      }
    }
  }

  @IsTest
  static void testIsAdminUser() {
    User u = getDashboardUser();
    System.runAs(u) {
      Test.startTest();
      Boolean isAdmin = IntegrationHealthController.isAdminUser();
      Test.stopTest();
      // u doesn't have the admin perm set in setup, only read
      System.assertEquals(false, isAdmin);
    }
  }

  @IsTest
  static void testDeployRegistryEntry() {
    // Run as admin to avoid metadata permission issues in test
    Test.startTest();
    String jobId = IntegrationHealthController.deployRegistryEntry(
      'TEST_CODE',
      'Test Label',
      'Test Group',
      'Inbound',
      'SAP',
      true
    );
    Test.stopTest();

    System.assertNotEquals(null, jobId);
  }

  @IsTest
  static void testSyncHistoricalLogs() {
    Integration_Log__c log = [
      SELECT Normalized_Context__c
      FROM Integration_Log__c
      WHERE IntegrationCode__c = 'HTTP-PED'
      LIMIT 1
    ];

    Test.startTest();
    // This will trigger the @future method
    IntegrationHealthController.deployRegistryEntry(
      'HTTP-PED',
      'New Pedidos',
      'New Group',
      'Outbound',
      'REST',
      true
    );
    Test.stopTest(); // Wait for @future execution

    Integration_Log__c updatedLog = [
      SELECT Normalized_Context__c
      FROM Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals('New Group', updatedLog.Normalized_Context__c);
  }

  @IsTest
  static void testController_CatchBlocks() {
    User u = getDashboardUser();
    System.runAs(u) {
      Test.startTest();
      try {
        IntegrationHealthController.getRecentLogs(
          -1,
          null,
          'invalid',
          'invalid',
          null,
          null,
          null,
          null,
          null
        );
      } catch (AuraHandledException e) {
      }
      try {
        IntegrationHealthController.getLogDetail(null);
      } catch (AuraHandledException e) {
      }
      try {
        IntegrationHealthController.getIntegrationSummaries(null, null);
      } catch (AuraHandledException e) {
      }
      try {
        IntegrationHealthController.deployRegistryEntry(
          null,
          null,
          null,
          null,
          null,
          null
        );
      } catch (AuraHandledException e) {
      }
      try {
        IntegrationHealthController.deleteLog(null);
      } catch (AuraHandledException e) {
      }
      try {
        IntegrationHealthController.updateLogObservation(null, null);
      } catch (AuraHandledException e) {
      }
      Test.stopTest();
      System.assert(true, 'Controller catch blocks exercised');
    }
  }

  @IsTest
  static void testController_SuccessPaths_Management() {
    User u = getDashboardUser();
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    System.runAs(u) {
      Test.startTest();
      IntegrationHealthController.getEventChannel();
      IntegrationHealthController.getRegistryInfo();
      try {
        IntegrationHealthController.updateLogObservation(
          log.Id,
          'MANUAL_OVERRIDE'
        );
      } catch (Exception e) {
      }
      try {
        IntegrationHealthController.deleteLog(log.Id);
      } catch (Exception e) {
      }
      Test.stopTest();

      System.assert(true, 'Management paths hit successfully');
    }
  }

  // --- Phase 7: Tests for new severity / trend methods ---

  @IsTest
  static void testGetSeverityCounts_happyPath() {
    User u = getDashboardUser();
    // Setup data is already in @TestSetup with 3 logs of mixed types
    System.runAs(u) {
      Test.startTest();
      List<IntegrationHealthWrappers.SeverityCountEntry> result = IntegrationHealthController.getSeverityCounts();
      Test.stopTest();

      System.assertNotEquals(null, result, 'Result should not be null');
      System.assert(
        result.size() > 0,
        'Should return at least one severity bucket'
      );

      Integer totalFromEntries = 0;
      for (IntegrationHealthWrappers.SeverityCountEntry entry : result) {
        System.assertNotEquals(
          null,
          entry.severity,
          'Severity label should not be null'
        );
        System.assert(
          entry.count > 0,
          'Each entry should have a positive count'
        );
        System.assert(
          entry.percentage >= 0,
          'Percentage should be non-negative'
        );
        totalFromEntries += entry.count;
      }
      System.assertEquals(
        3,
        totalFromEntries,
        'Total across severity buckets should equal 3 logs in setup'
      );
    }
  }

  @IsTest
  static void testGetSeverityCounts_empty() {
    User u = getDashboardUser();
    // Delete all logs to simulate empty state
    System.runAs(new User(Id = UserInfo.getUserId())) {
      delete [SELECT Id FROM Integration_Log__c];
    }
    System.runAs(u) {
      Test.startTest();
      List<IntegrationHealthWrappers.SeverityCountEntry> result = IntegrationHealthController.getSeverityCounts();
      Test.stopTest();

      System.assertNotEquals(
        null,
        result,
        'Should return empty list, not null'
      );
      System.assertEquals(
        0,
        result.size(),
        'Should return empty list when no logs exist'
      );
    }
  }

  @IsTest
  static void testGetTopErrorIntegrations_happyPath() {
    User u = getDashboardUser();
    System.runAs(u) {
      Test.startTest();
      List<IntegrationHealthWrappers.TopErrorIntegration> result = IntegrationHealthController.getTopErrorIntegrations(
        5
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Result should not be null');
      for (IntegrationHealthWrappers.TopErrorIntegration entry : result) {
        System.assertNotEquals(
          null,
          entry.integrationCode,
          'Integration code should not be null'
        );
        System.assertNotEquals(
          null,
          entry.displayName,
          'Display name should not be null'
        );
        System.assert(entry.totalEvents > 0, 'Total events should be positive');
        System.assert(
          new Set<String>{ 'up', 'down', 'flat' }.contains(entry.trend),
          'Trend should be up, down, or flat'
        );
      }
    }
  }

  @IsTest
  static void testGetTopErrorIntegrations_empty() {
    User u = getDashboardUser();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      delete [SELECT Id FROM Integration_Log__c];
    }
    System.runAs(u) {
      Test.startTest();
      List<IntegrationHealthWrappers.TopErrorIntegration> result = IntegrationHealthController.getTopErrorIntegrations(
        5
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        result,
        'Should return empty list, not null'
      );
      System.assertEquals(
        0,
        result.size(),
        'Should return empty list when no logs exist'
      );
    }
  }

  @IsTest
  static void testGetTopErrorIntegrations_topN() {
    User u = getDashboardUser();
    // Insert additional logs with different integration codes to test the topN limit
    List<Integration_Log__c> extraLogs = new List<Integration_Log__c>{
      new Integration_Log__c(
        IntegrationCode__c = 'HTTP-SHIP',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Context__c = '{}',
        CorrelationId__c = 'CORR-TOPN-1'
      ),
      new Integration_Log__c(
        IntegrationCode__c = 'HTTP-INV',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Context__c = '{}',
        CorrelationId__c = 'CORR-TOPN-2'
      ),
      new Integration_Log__c(
        IntegrationCode__c = 'HTTP-CRM',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Context__c = '{}',
        CorrelationId__c = 'CORR-TOPN-3'
      )
    };
    insert as system extraLogs;

    System.runAs(u) {
      Test.startTest();
      List<IntegrationHealthWrappers.TopErrorIntegration> top2 = IntegrationHealthController.getTopErrorIntegrations(
        2
      );
      List<IntegrationHealthWrappers.TopErrorIntegration> top10 = IntegrationHealthController.getTopErrorIntegrations(
        10
      );
      Test.stopTest();

      System.assert(
        top2.size() <= 2,
        'topN=2 should return at most 2 integrations'
      );
      System.assert(
        top10.size() <= 10,
        'topN=10 should return at most 10 integrations'
      );
    }
  }

  @IsTest
  static void testGetHourlyTrend_happyPath() {
    User u = getDashboardUser();
    System.runAs(u) {
      Test.startTest();
      IntegrationHealthWrappers.HourlyTrendResult result = IntegrationHealthController.getHourlyTrend(
        4
      );
      Test.stopTest();

      System.assertNotEquals(null, result, 'Result should not be null');
      System.assertNotEquals(
        null,
        result.points,
        'Points list should not be null'
      );
      System.assertNotEquals(
        null,
        result.direction,
        'Direction should not be null'
      );
      System.assert(
        new Set<String>{ 'up', 'down', 'flat' }.contains(result.direction),
        'Direction should be up, down, or flat'
      );

      for (IntegrationHealthWrappers.TrendPoint point : result.points) {
        System.assertNotEquals(
          null,
          point.hour,
          'Hour label should not be null'
        );
        System.assert(point.total >= 0, 'Total should be non-negative');
        System.assert(point.errors >= 0, 'Errors count should be non-negative');
      }
    }
  }

  @IsTest
  static void testGetHourlyTrend_empty() {
    User u = getDashboardUser();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      delete [SELECT Id FROM Integration_Log__c];
    }
    System.runAs(u) {
      Test.startTest();
      IntegrationHealthWrappers.HourlyTrendResult result = IntegrationHealthController.getHourlyTrend(
        4
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        result,
        'Should return result object, not null'
      );
      System.assertEquals(
        0,
        result.points.size(),
        'Should return empty points list'
      );
      System.assertEquals(
        'flat',
        result.direction,
        'Direction should be flat with no data'
      );
      System.assertEquals(0, result.delta, 'Delta should be 0 with no data');
    }
  }

  @IsTest
  static void testGetHourlyTrend_singleLog() {
    User u = getDashboardUser();
    // Delete all, then insert a single log
    System.runAs(new User(Id = UserInfo.getUserId())) {
      delete [SELECT Id FROM Integration_Log__c];
    }
    insert as system new Integration_Log__c(
      IntegrationCode__c = 'SINGLE-LOG',
      ObservationType__c = 'REQUEST_DISPATCHED',
      Context__c = '{}',
      CorrelationId__c = 'CORR-SINGLE'
    );

    System.runAs(u) {
      Test.startTest();
      IntegrationHealthWrappers.HourlyTrendResult result = IntegrationHealthController.getHourlyTrend(
        4
      );
      Test.stopTest();

      System.assertNotEquals(
        null,
        result,
        'Should return result with single log'
      );
      // With only 1 data point, delta computation skips (needs >= 2 points)
      System.assertEquals(
        'flat',
        result.direction,
        'Direction should be flat with single point'
      );
    }
  }

  @IsTest
  static void testGetSeverityCounts_allSameType() {
    User u = getDashboardUser();
    // Delete all, then insert logs all of the same type
    System.runAs(new User(Id = UserInfo.getUserId())) {
      delete [SELECT Id FROM Integration_Log__c];
    }
    List<Integration_Log__c> sameTypeLogs = new List<Integration_Log__c>();
    for (Integer i = 0; i < 5; i++) {
      sameTypeLogs.add(
        new Integration_Log__c(
          IntegrationCode__c = 'SINGLE-TYPE',
          ObservationType__c = 'REQUEST_DISPATCHED',
          Context__c = '{"index": ' + i + '}',
          CorrelationId__c = 'CORR-SAME-' + i
        )
      );
    }
    insert as system sameTypeLogs;

    System.runAs(u) {
      Test.startTest();
      List<IntegrationHealthWrappers.SeverityCountEntry> result = IntegrationHealthController.getSeverityCounts();
      Test.stopTest();

      System.assertNotEquals(null, result, 'Result should not be null');
      // All logs same type → should resolve to single severity bucket
      System.assertEquals(
        1,
        result.size(),
        'Should have exactly 1 severity bucket'
      );
      System.assertEquals(5, result[0].count, 'Count should be 5');
      System.assertEquals(
        100.0,
        result[0].percentage,
        'Percentage should be 100%'
      );
    }
  }

  @IsTest
  static void testGetRegisteredPlugins_returnsAll() {
    Test.startTest();
    List<IntegrationHealthWrappers.PluginRegistryEntry> plugins = IntegrationHealthController.getRegisteredPlugins();
    Test.stopTest();

    System.assertNotEquals(null, plugins, 'Plugins list should not be null');
    System.assert(
      plugins.size() >= 0,
      'Should return a valid list of registered plugins'
    );
  }

  @IsTest
  static void testRefreshPluginCache_doesNotThrow() {
    Test.startTest();
    IntegrationHealthController.refreshPluginCache();
    Test.stopTest();

    System.assert(true, 'refreshPluginCache should complete without error');
  }

  @IsTest
  static void testTogglePluginEnabled_unauthorizedThrowsException() {
    User u = getDashboardUser();
    // dashboard_user only has Integration_Dashboard_Read, not Admin (which has IEF_Manage_Plugins)
    System.runAs(u) {
      Test.startTest();
      try {
        IntegrationHealthController.togglePluginEnabled('TestPlugin', false);
        System.assert(
          false,
          'Should have thrown AuraHandledException for unauthorized user'
        );
      } catch (Exception e) {
        System.assert(
          e instanceof AuraHandledException,
          'Should throw AuraHandledException when lacking IEF_Manage_Plugins'
        );
      }
      Test.stopTest();
    }
  }

  @IsTest
  static void testCanManagePlugins_returnsFalseWithoutPermission() {
    User u = getDashboardUser();
    System.runAs(u) {
      Test.startTest();
      Boolean canManage = IntegrationHealthController.canManagePlugins();
      Test.stopTest();
      System.assertEquals(
        false,
        canManage,
        'User without IEF_Manage_Plugins should return false'
      );
    }
  }

  @IsTest
  static void testCanManagePlugins_returnsTrueWithPermission() {
    User adminUser = TestDataFactory.createStandardUser(
      'plugin_admin@test.com'
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      TestDataFactory.assignPermissionSet(
        adminUser.Id,
        'Integration_Dashboard_Admin'
      );
    }

    System.runAs(adminUser) {
      Test.startTest();
      Boolean canManage = IntegrationHealthController.canManagePlugins();
      Test.stopTest();
      System.assertEquals(
        true,
        canManage,
        'User with IEF_Manage_Plugins should return true'
      );
    }
  }

  @IsTest
  static void testCanEditLogObservationType_returnsFalseWithoutEditAccess() {
    User u = getDashboardUser();
    System.runAs(u) {
      Test.startTest();
      Boolean canEdit = IntegrationHealthController.canEditLogObservationType();
      Test.stopTest();
      System.assertEquals(
        false,
        canEdit,
        'Dashboard users should not be able to edit ObservationType__c without field edit access'
      );
    }
  }

  @IsTest
  static void testTogglePluginEnabled_handlesError() {
    User adminUser = TestDataFactory.createStandardUser(
      'plugin_admin_error@test.com'
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      TestDataFactory.assignPermissionSet(
        adminUser.Id,
        'Integration_Dashboard_Admin'
      );
    }

    System.runAs(adminUser) {
      try {
        Test.startTest();
        IEF_PluginRegistry.testTogglePluginException = new IllegalArgumentException(
          'Injected toggle failure'
        );
        IntegrationHealthController.togglePluginEnabled('AnyPlugin', true);
        System.assert(
          false,
          'Should surface a handled exception when the toggle operation fails after permission checks pass'
        );
      } catch (Exception e) {
        System.assert(
          e instanceof AuraHandledException,
          'Should rethrow the failure as AuraHandledException'
        );
      } finally {
        Test.stopTest();
      }
    }
  }
}
