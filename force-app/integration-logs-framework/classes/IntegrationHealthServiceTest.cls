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
          Context__c = '{"index": ' + i + '}',
          Normalized_Context__c = 'ERP Systems',
          OccurredAt__c = Datetime.now().addHours(-i)
        )
      );
    }
    insert as system logs;
  }

  @IsTest
  static void getLogPage_ReturnsPage_WhenLogsExist() {
    Test.startTest();
    IntegrationHealthWrappers.LogPage page = IntegrationHealthService.getLogPage(
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
    System.assertNotEquals(
      null,
      page.nextKey,
      'Should have next key for pagination'
    );
  }

  @IsTest
  static void getLogPage_FiltersBy_IntegrationCode() {
    Test.startTest();
    IntegrationHealthWrappers.LogPage page = IntegrationHealthService.getLogPage(
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
  static void getLogPage_UseDefaultPageSize_WhenNullProvided() {
    Test.startTest();
    IntegrationHealthWrappers.LogPage page = IntegrationHealthService.getLogPage(
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
    System.assertNotEquals(null, detail.log, 'Should have log');
    System.assertEquals(log.Id, detail.log.Id, 'Should match requested log');
  }

  @IsTest
  static void getLogDetail_ReturnsNull_WhenLogNotFound() {
    Id fakeId = '001000000000000AAA';

    Test.startTest();
    IntegrationHealthWrappers.LogDetailWrapper detail = IntegrationHealthService.getLogDetail(
      fakeId
    );
    Test.stopTest();

    System.assertEquals(
      null,
      detail,
      'Should return null for non-existent log'
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
    IntegrationHealthWrappers.FilterOptionsWrapper options = IntegrationHealthService.getFilterOptions();
    Test.stopTest();

    System.assertNotEquals(null, options, 'Should return filter options');
  }
}
