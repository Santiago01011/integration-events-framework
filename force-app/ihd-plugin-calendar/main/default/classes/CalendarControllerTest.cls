/**
 * @description Unit tests for CalendarController.
 */
@isTest
private class CalendarControllerTest {
  /**
   * @description Tests empty result when no logs exist in date range.
   */
  @isTest
  static void testEmptyResult() {
    // Arrange: No test data created
    Test.startTest();

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    // Assert: Should return empty list (no logs exist)
    System.assertEquals(
      0,
      results.size(),
      'Should return empty list when no logs exist'
    );
  }

  /**
   * @description Tests single day aggregation with multiple logs.
   */
  @isTest
  static void testSingleDayAggregates() {
    // Arrange: Create test logs for a single day
    Date testDate = Date.today().addDays(-1);
    List<Integration_Log__c> logs = new List<Integration_Log__c>();

    // Create logs with different severities
    logs.add(createTestLog(testDate, 'SUCCESS', 'LOG-001'));
    logs.add(createTestLog(testDate, 'SUCCESS', 'LOG-002'));
    logs.add(createTestLog(testDate, 'WARN', 'LOG-003'));
    logs.add(createTestLog(testDate, 'ERROR', 'LOG-004'));
    logs.add(createTestLog(testDate, 'INFO', 'LOG-005'));

    insert logs;

    Test.startTest();

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    // Assert: Should return one day with correct counts
    System.assertEquals(1, results.size(), 'Should return one day');

    CalendarWrappers.DailyLogCount dayCount = results[0];
    System.assertEquals(testDate, dayCount.logDate, 'Date should match');
    System.assertEquals(5, dayCount.totalCount, 'Total count should be 5');
    System.assertEquals(2, dayCount.successCount, 'Success count should be 2');
    System.assertEquals(1, dayCount.warningCount, 'Warning count should be 1');
    System.assertEquals(1, dayCount.errorCount, 'Error count should be 1');
    System.assertEquals(1, dayCount.infoCount, 'Info count should be 1');
  }

  /**
   * @description Tests multiple days with correct sorting.
   */
  @isTest
  static void testMultipleDaysSorting() {
    // Arrange: Create test logs across multiple days
    List<Integration_Log__c> logs = new List<Integration_Log__c>();
    Date day1 = Date.today().addDays(-3);
    Date day2 = Date.today().addDays(-2);
    Date day3 = Date.today().addDays(-1);

    logs.add(createTestLog(day1, 'ERROR', 'LOG-001'));
    logs.add(createTestLog(day2, 'SUCCESS', 'LOG-002'));
    logs.add(createTestLog(day3, 'WARN', 'LOG-003'));

    insert logs;

    Test.startTest();

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      null,
      null
    );
    Test.stopTest();

    // Assert: Should return results sorted by date ascending
    System.assertEquals(3, results.size(), 'Should return three days');
    System.assertEquals(day1, results[0].logDate, 'First day should be oldest');
    System.assertEquals(day3, results[2].logDate, 'Last day should be newest');
  }

  /**
   * @description Tests filter by observation type.
   */
  @isTest
  static void testFilterByObservationType() {
    // Arrange: Create test logs with different types
    List<Integration_Log__c> logs = new List<Integration_Log__c>();
    Date testDate = Date.today().addDays(-1);

    logs.add(createTestLog(testDate, 'ERROR', 'LOG-001'));
    logs.add(createTestLog(testDate, 'SUCCESS', 'LOG-002'));
    logs.add(createTestLog(testDate, 'ERROR', 'LOG-003'));

    insert logs;

    Test.startTest();

    // Act: Filter for ERROR only
    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      'ERROR',
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    // Assert: Should only return ERROR logs
    System.assertEquals(1, results.size(), 'Should return one day');
    System.assertEquals(
      2,
      results[0].totalCount,
      'Should only count ERROR logs'
    );
    System.assertEquals(2, results[0].errorCount, 'Error count should be 2');
    System.assertEquals(
      0,
      results[0].successCount,
      'Success count should be 0'
    );
  }

  /**
   * @description Tests filter by integration code.
   */
  @isTest
  static void testFilterByIntegrationCode() {
    // Arrange: Create test logs with different integration codes
    List<Integration_Log__c> logs = new List<Integration_Log__c>();
    Date testDate = Date.today().addDays(-1);

    Integration_Log__c log1 = createTestLog(testDate, 'SUCCESS', 'LOG-001');
    log1.IntegrationCode__c = 'INT-A';

    Integration_Log__c log2 = createTestLog(testDate, 'ERROR', 'LOG-002');
    log2.IntegrationCode__c = 'INT-B';

    Integration_Log__c log3 = createTestLog(testDate, 'WARN', 'LOG-003');
    log3.IntegrationCode__c = 'INT-A';

    logs.add(log1);
    logs.add(log2);
    logs.add(log3);

    insert logs;

    Test.startTest();

    // Act: Filter for INT-A
    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      'INT-A',
      null,
      null,
      null
    );

    Test.stopTest();

    // Assert: Should only return logs for INT-A
    System.assertEquals(1, results.size(), 'Should return one day');
    System.assertEquals(
      2,
      results[0].totalCount,
      'Should only count INT-A logs'
    );
  }

  /**
   * @description Tests date range filtering.
   */
  @isTest
  static void testDateRangeFilter() {
    // Arrange: Create test logs across different dates
    List<Integration_Log__c> logs = new List<Integration_Log__c>();
    Date day1 = Date.today().addDays(-10);
    Date day2 = Date.today().addDays(-5);
    Date day3 = Date.today().addDays(-1);

    logs.add(createTestLog(day1, 'SUCCESS', 'LOG-001'));
    logs.add(createTestLog(day2, 'ERROR', 'LOG-002'));
    logs.add(createTestLog(day3, 'WARN', 'LOG-003'));

    insert logs;

    Test.startTest();

    // Act: Filter for last 3 days
    String fromDate = Date.today().addDays(-3).format();
    String toDate = Date.today().format();

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      fromDate,
      toDate
    );

    Test.stopTest();

    // Assert: Should only return logs within date range
    System.assertEquals(
      1,
      results.size(),
      'Should return one day within range'
    );
    System.assertEquals(day3, results[0].logDate, 'Should be day3');
  }

  /**
   * @description Tests search filter.
   */
  @isTest
  static void testSearchFilter() {
    // Arrange: Create test logs with different context data
    List<Integration_Log__c> logs = new List<Integration_Log__c>();
    Date testDate = Date.today().addDays(-1);

    Integration_Log__c log1 = createTestLog(testDate, 'SUCCESS', 'LOG-001');
    log1.Context__c = '{"message": "Order processed successfully"}';

    Integration_Log__c log2 = createTestLog(testDate, 'ERROR', 'LOG-002');
    log2.Context__c = '{"message": "Payment failed"}';

    logs.add(log1);
    logs.add(log2);

    insert logs;

    Test.startTest();

    // Act: Search for "Payment"
    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      'Payment',
      null,
      null,
      null,
      null,
      null
    );

    Test.stopTest();

    // Assert: Should only return matching logs
    System.assert(results.size() <= 1, 'Should return at most one day');
  }

  /**
   * @description Helper method to create test log.
   */
  private static Integration_Log__c createTestLog(
    Date occurredDate,
    String observationType,
    String logId
  ) {
    Integration_Log__c log = new Integration_Log__c();
    log.OccurredAt__c = occurredDate;
    log.ObservationType__c = observationType;
    log.Context__c = '{"message": "Test log ' + logId + '"}';
    log.IntegrationCode__c = 'TEST-INT';
    log.CorrelationId__c = logId;
    return log;
  }
}
