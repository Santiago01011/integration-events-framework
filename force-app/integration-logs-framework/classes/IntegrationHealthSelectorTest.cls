/**
 * @description Test class for IntegrationHealthSelector.
 * Validates data access layer for Integration Health components.
 */
@IsTest
private class IntegrationHealthSelectorTest {
  @TestSetup
  static void makeData() {
    List<Integration_Log__c> logs = new List<Integration_Log__c>();
    for (Integer i = 0; i < 5; i++) {
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
      'admin_test_selector@test.com'
    );

    // Assign permission set in a separate transaction context to avoid mixed DML if needed,
    // though usually fine in setup. Doing it here ensures the user returned has perms.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      TestDataFactory.assignPermissionSet(
        adminUser.Id,
        'Integration_Dashboard_Admin'
      );
    }
    return adminUser;
  }

  @IsTest
  static void queryLogs_ReturnsResults_WhenLogsExist() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<Integration_Log__c> logs = IntegrationHealthSelector.queryLogs(
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
      Test.stopTest();

      System.assertNotEquals(null, logs, 'Should return logs');
      System.assertEquals(5, logs.size(), 'Should return 5 logs');
    }
  }

  @IsTest
  static void queryLogs_FiltersBy_IntegrationCode() {
    insert as system new Integration_Log__c(
      IntegrationCode__c = 'DIFFERENT_CODE',
      ObservationType__c = 'OTHER_OP',
      CorrelationId__c = 'corr-other',
      Context__c = '{}'
    );

    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<Integration_Log__c> logs = IntegrationHealthSelector.queryLogs(
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
        5,
        logs.size(),
        'Should filter to SAP_ORDERS logs only'
      );
    }
  }

  @IsTest
  static void queryLogs_FiltersBy_CorrelationId() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<Integration_Log__c> logs = IntegrationHealthSelector.queryLogs(
        10,
        null,
        null,
        null,
        null,
        null,
        'corr-0',
        null,
        null
      );
      Test.stopTest();

      System.assertEquals(
        1,
        logs.size(),
        'Should return 1 log with matching correlation'
      );
    }
  }

  @IsTest
  static void queryLogs_SupportsSearch_WhenProvided() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<Integration_Log__c> logs = IntegrationHealthSelector.queryLogs(
        10,
        'HTTP',
        null,
        null,
        null,
        null,
        null,
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(
        0,
        logs.size(),
        'Should find logs matching search'
      );
    }
  }

  @IsTest
  static void getLogById_ReturnsLog_WhenExists() {
    Integration_Log__c expectedLog = [
      SELECT Id
      FROM Integration_Log__c
      LIMIT 1
    ];

    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      Integration_Log__c log = IntegrationHealthSelector.getLogById(
        expectedLog.Id
      );
      Test.stopTest();

      System.assertNotEquals(null, log, 'Should return log');
      System.assertEquals(expectedLog.Id, log.Id, 'Should match requested ID');
    }
  }

  @IsTest
  static void getLogById_ReturnsNull_WhenNotFound() {
    Id fakeId = '001000000000000AAA';

    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      Integration_Log__c log = IntegrationHealthSelector.getLogById(fakeId);
      Test.stopTest();

      System.assertEquals(null, log, 'Should return null for non-existent ID');
    }
  }

  @IsTest
  static void getIntegrationDefinitions_ReturnsMap() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      Map<String, idhIntegration_Definition__mdt> registry = IntegrationHealthSelector.getIntegrationDefinitions();
      Test.stopTest();

      System.assertNotEquals(null, registry, 'Should return registry map');
    }
  }

  @IsTest
  static void getLogSummaries_ReturnsAggregates() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<AggregateResult> summaries = IntegrationHealthSelector.getLogSummaries();
      Test.stopTest();

      System.assertNotEquals(null, summaries, 'Should return summaries');
    }
  }

  @IsTest
  static void getLogCountsByCode_ReturnsAggregates() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<AggregateResult> counts = IntegrationHealthSelector.getLogCountsByCode();
      Test.stopTest();

      System.assertNotEquals(null, counts, 'Should return counts');
    }
  }

  @IsTest
  static void isAdminUser_ReturnsBoolean() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      // Since this user has the permission set which grants Delete access (updated previously)
      Boolean isAdmin = IntegrationHealthSelector.isAdminUser();
      Test.stopTest();

      System.assertEquals(
        true,
        isAdmin,
        'Should return true for admin user with permissions'
      );
    }
  }

  @IsTest
  static void fieldExists_ReturnsTrue_ForValidField() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      Boolean exists = IntegrationHealthSelector.fieldExists(
        'IntegrationCode__c'
      );
      Test.stopTest();

      System.assertEquals(true, exists, 'Should return true for valid field');
    }
  }

  @IsTest
  static void fieldExists_ReturnsFalse_ForInvalidField() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      Boolean exists = IntegrationHealthSelector.fieldExists(
        'NonExistentField__c'
      );
      Test.stopTest();

      System.assertEquals(
        false,
        exists,
        'Should return false for invalid field'
      );
    }
  }

  @IsTest
  static void getEvaluationRules_ReturnsList() {
    User admin = getAdminUser();

    System.runAs(admin) {
      Test.startTest();
      List<idhIntegration_Evaluation_Rule__mdt> rules = IntegrationHealthSelector.getEvaluationRules(
        'HTTP_REQUEST'
      );
      Test.stopTest();

      System.assertNotEquals(null, rules, 'Should return rules list');
    }
  }
}
