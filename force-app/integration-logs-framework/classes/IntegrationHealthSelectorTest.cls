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
          Context__c = '{"index": ' + i + '}',
          Normalized_Context__c = 'ERP Systems',
          OccurredAt__c = Datetime.now().addHours(-i)
        )
      );
    }
    insert as system logs;
  }

  @IsTest
  static void getRecentLogs_ReturnsResults_WhenLogsExist() {
    Test.startTest();
    List<Integration_Log__c> logs = IntegrationHealthSelector.getRecentLogs(
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

  @IsTest
  static void getRecentLogs_FiltersBy_IntegrationCode() {
    insert as system new Integration_Log__c(
      IntegrationCode__c = 'DIFFERENT_CODE',
      ObservationType__c = 'OTHER_OP',
      CorrelationId__c = 'corr-other',
      Context__c = '{}',
      OccurredAt__c = Datetime.now()
    );

    Test.startTest();
    List<Integration_Log__c> logs = IntegrationHealthSelector.getRecentLogs(
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
    for (Integration_Log__c log : logs) {
      System.assert(
        log.IntegrationCode__c.contains('SAP'),
        'All logs should match filter'
      );
    }
  }

  @IsTest
  static void getRecentLogs_FiltersBy_CorrelationId() {
    Test.startTest();
    List<Integration_Log__c> logs = IntegrationHealthSelector.getRecentLogs(
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
    System.assertEquals(
      'corr-0',
      logs[0].CorrelationId__c,
      'Should match correlation ID'
    );
  }

  @IsTest
  static void getRecentLogs_SupportsSearch_WhenProvided() {
    Test.startTest();
    List<Integration_Log__c> logs = IntegrationHealthSelector.getRecentLogs(
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

    System.assertNotEquals(0, logs.size(), 'Should find logs matching search');
  }

  @IsTest
  static void getLogById_ReturnsLog_WhenExists() {
    Integration_Log__c expectedLog = [
      SELECT Id
      FROM Integration_Log__c
      LIMIT 1
    ];

    Test.startTest();
    Integration_Log__c log = IntegrationHealthSelector.getLogById(
      expectedLog.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, log, 'Should return log');
    System.assertEquals(expectedLog.Id, log.Id, 'Should match requested ID');
  }

  @IsTest
  static void getLogById_ReturnsNull_WhenNotFound() {
    Id fakeId = '001000000000000AAA';

    Test.startTest();
    Integration_Log__c log = IntegrationHealthSelector.getLogById(fakeId);
    Test.stopTest();

    System.assertEquals(null, log, 'Should return null for non-existent ID');
  }

  @IsTest
  static void getRegistryMap_ReturnsMap_WithMetadata() {
    Test.startTest();
    Map<String, idhIntegration_Definition__mdt> registry = IntegrationHealthSelector.getRegistryMap();
    Test.stopTest();

    System.assertNotEquals(null, registry, 'Should return registry map');
  }

  @IsTest
  static void getLogSummaries_ReturnsAggregates() {
    Test.startTest();
    List<AggregateResult> summaries = IntegrationHealthSelector.getLogSummaries();
    Test.stopTest();

    System.assertNotEquals(null, summaries, 'Should return summaries');
  }

  @IsTest
  static void isAdminUser_ReturnsBoolean() {
    Test.startTest();
    Boolean isAdmin = IntegrationHealthSelector.isAdminUser();
    Test.stopTest();

    System.assertNotEquals(null, isAdmin, 'Should return boolean');
  }

  @IsTest
  static void fieldExists_ReturnsTrue_ForValidField() {
    Test.startTest();
    Boolean exists = IntegrationHealthSelector.fieldExists(
      'IntegrationCode__c'
    );
    Test.stopTest();

    System.assertEquals(true, exists, 'Should return true for valid field');
  }

  @IsTest
  static void fieldExists_ReturnsFalse_ForInvalidField() {
    Test.startTest();
    Boolean exists = IntegrationHealthSelector.fieldExists(
      'NonExistentField__c'
    );
    Test.stopTest();

    System.assertEquals(false, exists, 'Should return false for invalid field');
  }

  @IsTest
  static void getAccessibleFields_ReturnsCommaSeparated() {
    List<String> fieldNames = new List<String>{ 'Id', 'IntegrationCode__c' };

    Test.startTest();
    String fields = IntegrationHealthSelector.getAccessibleFields(fieldNames);
    Test.stopTest();

    System.assertNotEquals(null, fields, 'Should return fields string');
    System.assert(fields.contains('Id'), 'Should contain Id field');
  }

  @IsTest
  static void getLogCountsByCode_ReturnsAggregates() {
    Test.startTest();
    List<AggregateResult> counts = IntegrationHealthSelector.getLogCountsByCode();
    Test.stopTest();

    System.assertNotEquals(null, counts, 'Should return counts');
  }
}
