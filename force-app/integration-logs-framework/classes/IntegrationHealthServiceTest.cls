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

  @IsTest
  static void getPagedLogs_ReturnsPage_WhenLogsExist() {
    Test.startTest();
    IntegrationHealthWrappers.IntegrationLogPage page = IntegrationHealthService.getPagedLogs(
      5,
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
    System.assertEquals(5, page.records.size(), 'Should return page size of 5');
  }

  @IsTest
  static void getPagedLogs_FiltersBy_IntegrationCode() {
    Test.startTest();
    IntegrationHealthWrappers.IntegrationLogPage page = IntegrationHealthService.getPagedLogs(
      10,
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

  @IsTest
  static void getPagedLogs_UseDefaultPageSize_WhenNullProvided() {
    Test.startTest();
    IntegrationHealthWrappers.IntegrationLogPage page = IntegrationHealthService.getPagedLogs(
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
    System.assertNotEquals(0, page.records.size(), 'Should return records');
  }

  @IsTest
  static void getLogDetail_ReturnsWrapper_WhenLogExists() {
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    Test.startTest();
    IntegrationHealthWrappers.LogDetailWrapper detail = IntegrationHealthService.getLogDetail(
      log.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, detail, 'Should return detail wrapper');
    System.assertNotEquals(null, detail.record, 'Should have record');
    System.assertEquals(log.Id, detail.record.Id, 'Should match requested log');
  }

  @IsTest
  static void getLogDetail_ThrowsException_WhenLogNotFound() {
    Id fakeId = '001000000000000AAA';
    Boolean exceptionThrown = false;

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

  @IsTest
  static void getLogDetail_ThrowsException_WhenIdIsNull() {
    Boolean exceptionThrown = false;

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

  @IsTest
  static void getIntegrationSummaries_ReturnsList() {
    Test.startTest();
    List<IntegrationHealthWrappers.IntegrationSummary> summaries = IntegrationHealthService.getIntegrationSummaries(
      false,
      false
    );
    Test.stopTest();

    System.assertNotEquals(null, summaries, 'Should return summaries');
  }

  @IsTest
  static void getIntegrationSummaries_IncludesUnregistered_WhenFlagSet() {
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

  @IsTest
  static void getIntegrationSummaries_ExpandsByAttributes_WhenFlagSet() {
    Test.startTest();
    List<IntegrationHealthWrappers.IntegrationSummary> summaries = IntegrationHealthService.getIntegrationSummaries(
      false,
      true
    );
    Test.stopTest();

    System.assertNotEquals(null, summaries, 'Should return expanded summaries');
  }

  @IsTest
  static void getIntegrationSummaries_HandlesNullFlags() {
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

  @IsTest
  static void getRegistryInfo_ReturnsList() {
    Test.startTest();
    List<IntegrationHealthWrappers.RegistryEntry> entries = IntegrationHealthService.getRegistryInfo();
    Test.stopTest();

    System.assertNotEquals(null, entries, 'Should return registry entries');
  }

  @IsTest
  static void getFilterOptions_ReturnsWrapper() {
    Test.startTest();
    IntegrationHealthWrappers.FilterOptions options = IntegrationHealthService.getFilterOptions();
    Test.stopTest();

    System.assertNotEquals(null, options, 'Should return filter options');
    System.assertNotEquals(
      null,
      options.observationTypes,
      'Should have observation types'
    );
    System.assertNotEquals(
      null,
      options.integrationCodes,
      'Should have integration codes'
    );
  }

  @IsTest
  static void getEventChannel_ReturnsChannelPath() {
    Test.startTest();
    String channel = IntegrationHealthService.getEventChannel();
    Test.stopTest();

    System.assert(
      channel.startsWith('/event/'),
      'Should return event channel path'
    );
  }

  @IsTest
  static void deleteLog_DeletesRecord() {
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    Test.startTest();
    IntegrationHealthService.deleteLog(log.Id);
    Test.stopTest();

    List<Integration_Log__c> remaining = [
      SELECT Id
      FROM Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals(0, remaining.size(), 'Log should be deleted');
  }

  @IsTest
  static void deleteLog_HandlesNullId() {
    Test.startTest();
    IntegrationHealthService.deleteLog(null);
    Test.stopTest();

    System.assert(true, 'Should handle null ID without exception');
  }

  @IsTest
  static void updateLogObservation_UpdatesRecord() {
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    Test.startTest();
    IntegrationHealthService.updateLogObservation(log.Id, 'NEW_TYPE');
    Test.stopTest();

    Integration_Log__c updated = [
      SELECT ObservationType__c
      FROM Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals(
      'NEW_TYPE',
      updated.ObservationType__c,
      'Observation type should be updated'
    );
  }

  @IsTest
  static void updateLogObservation_HandlesNullId() {
    Test.startTest();
    IntegrationHealthService.updateLogObservation(null, 'NEW_TYPE');
    Test.stopTest();

    System.assert(true, 'Should handle null ID without exception');
  }

  @IsTest
  static void updateLogObservation_HandlesBlankType() {
    Integration_Log__c log = [SELECT Id FROM Integration_Log__c LIMIT 1];

    Test.startTest();
    IntegrationHealthService.updateLogObservation(log.Id, '');
    Test.stopTest();

    System.assert(true, 'Should handle blank type without exception');
  }
}
