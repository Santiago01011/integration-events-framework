/**
 * @description Unit tests for CalendarController.
 * Tests daily log count aggregation with proper DateTime handling.
 * CRITICAL: Uses DateTime.newInstance(Date, Time) to ensure consistent timezone
 * handling between test data creation and controller date filtering.
 */
@isTest
private class CalendarControllerTest {
  // Test observation types that match idhIntegration_Evaluation_Rule__mdt
  // Mapping: INTERNAL_CONTROLLER_ERROR -> ERROR, HTTP_RESPONSE -> SUCCESS
  // Note: Unknown types default to INFO severity
  private static final String OBS_ERROR = 'INTERNAL_CONTROLLER_ERROR';
  private static final String OBS_SUCCESS = 'HTTP_RESPONSE'; // Maps to SUCCESS in metadata

  @TestSetup
  static void setupTestData() {
    // Use Date.today() for consistent timezone handling
    // DateTime.newInstance(Date, Time) ensures logs are created on the expected calendar day
    Date today = Date.today();
    Date yesterday = today.addDays(-1);
    Date twoDaysAgo = today.addDays(-2);

    List<Integration_Log__c> logs = new List<Integration_Log__c>();

    // Today - multiple records at different times (tests time component handling)
    // CRITICAL: Use DateTime.newInstance with explicit Date to ensure timezone consistency
    logs.add(
      createTestLog(
        DateTime.newInstance(today, Time.newInstance(1, 0, 0, 0)),
        OBS_ERROR,
        'TODAY-ERROR-1'
      )
    );
    logs.add(
      createTestLog(
        DateTime.newInstance(today, Time.newInstance(5, 0, 0, 0)),
        OBS_ERROR,
        'TODAY-ERROR-2'
      )
    );
    logs.add(
      createTestLog(
        DateTime.newInstance(today, Time.newInstance(10, 0, 0, 0)),
        OBS_SUCCESS,
        'TODAY-SUCCESS-1'
      )
    );

    // Yesterday - tests multiple severity types on same day
    // Using PARTIAL_RESPONSE -> WARN, RETRY_ATTEMPT -> WARN (both map to WARN in metadata)
    logs.add(
      createTestLog(
        DateTime.newInstance(yesterday, Time.newInstance(2, 0, 0, 0)),
        'PARTIAL_RESPONSE',
        'YESTERDAY-PARTIAL-1'
      )
    );
    logs.add(
      createTestLog(
        DateTime.newInstance(yesterday, Time.newInstance(8, 0, 0, 0)),
        'RETRY_ATTEMPT',
        'YESTERDAY-RETRY-1'
      )
    );

    // Two days ago - tests multi-day aggregation
    logs.add(
      createTestLog(
        DateTime.newInstance(twoDaysAgo, Time.newInstance(14, 0, 0, 0)),
        OBS_SUCCESS,
        'TWO-DAYS-SUCCESS-1'
      )
    );

    insert logs;
  }

  /**
   * @description Tests that all records on a day are returned regardless of time.
   * This is the KEY test for the DateTime fix - records at different times on same day
   * should all be included when querying with endDateTime = 23:59:59.
   */
  @isTest
  static void testDateTimeBoundary_IncludesAllTimesOnSameDay() {
    Test.startTest();

    // CRITICAL: Use String.valueOf for ISO format (Date doesn't have format with pattern)
    String fromDate = String.valueOf(Date.today().addDays(-3));
    String toDate = String.valueOf(Date.today());

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      fromDate,
      toDate
    );

    Test.stopTest();

    // Assert: Should return 3 days (today, yesterday, two days ago)
    System.assertEquals(3, results.size(), 'Should return 3 days of data');

    // Find today's count
    CalendarWrappers.DailyLogCount todayCount = findCountByDate(
      results,
      Date.today()
    );
    System.assertNotEquals(null, todayCount, 'Today should have data');
    System.assertEquals(
      3,
      todayCount.totalCount,
      'Today should have 3 logs (2 ERROR + 1 SUCCESS)'
    );
    System.assertEquals(
      2,
      todayCount.errorCount,
      'Today should have 2 ERROR logs'
    );
    System.assertEquals(
      1,
      todayCount.successCount,
      'Today should have 1 SUCCESS log'
    );
  }

  /**
   * @description Tests date range filtering excludes records outside range.
   */
  @isTest
  static void testDateRangeFilter_ExcludesOutOfRange() {
    Test.startTest();

    // CRITICAL: Use String.valueOf for ISO format (Date doesn't have format with pattern)
    String today = String.valueOf(Date.today());

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      today,
      today
    );

    Test.stopTest();

    // Assert: Should return only today
    System.assertEquals(1, results.size(), 'Should return only today');
    System.assertEquals(3, results[0].totalCount, 'Today should have 3 logs');
  }

  /**
   * @description Tests default date range (last 90 days) returns data.
   */
  @isTest
  static void testDefaultDateRange_ReturnsLast90Days() {
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

    // Assert: Should include test data (within last 90 days)
    System.assert(results.size() >= 1, 'Should return at least one day');
  }

  /**
   * @description Tests filter by observation type.
   */
  @isTest
  static void testFilterByObservationType_ReturnsOnlyMatching() {
    Test.startTest();

    // CRITICAL: Use String.valueOf for ISO format (Date doesn't have format with pattern)
    String fromDate = String.valueOf(Date.today().addDays(-3));
    String toDate = String.valueOf(Date.today());

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      OBS_ERROR,
      null,
      null,
      fromDate,
      toDate
    );

    Test.stopTest();

    // Assert: Only ERROR logs should be counted
    for (CalendarWrappers.DailyLogCount dayCount : results) {
      System.assertEquals(
        0,
        dayCount.successCount + dayCount.warningCount + dayCount.infoCount,
        'Only ERROR logs should be present'
      );
    }
    // Total error count should be 2 (both from today)
    Integer totalErrors = 0;
    for (CalendarWrappers.DailyLogCount dc : results) {
      totalErrors += dc.errorCount;
    }
    System.assertEquals(2, totalErrors, 'Should have 2 ERROR logs total');
  }

  /**
   * @description Tests filter by integration code.
   */
  @isTest
  static void testFilterByIntegrationCode_ReturnsOnlyMatching() {
    Test.startTest();

    // CRITICAL: Use String.valueOf for ISO format (Date doesn't have format with pattern)
    String fromDate = String.valueOf(Date.today().addDays(-3));
    String toDate = String.valueOf(Date.today());

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      'TEST-INT',
      null,
      fromDate,
      toDate
    );

    Test.stopTest();

    // All test logs use 'TEST-INT' as integration code
    Integer totalCount = 0;
    for (CalendarWrappers.DailyLogCount dc : results) {
      totalCount += dc.totalCount;
    }
    System.assertEquals(6, totalCount, 'Should find all 6 test logs');
  }

  /**
   * @description Tests search filter matches integration code.
   * Note: Context__c cannot be filtered in aggregate queries (Long Text Area).
   */
  @isTest
  static void testSearchFilter_MatchesIntegrationCode() {
    Test.startTest();

    // CRITICAL: Use String.valueOf for ISO format (Date doesn't have format with pattern)
    String fromDate = String.valueOf(Date.today().addDays(-3));
    String toDate = String.valueOf(Date.today());

    // Search for "TEST" which matches integration code
    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      'TEST',
      null,
      null,
      null,
      fromDate,
      toDate
    );

    Test.stopTest();

    // Should match all 6 logs since they all have TEST-INT as integration code
    Integer totalCount = 0;
    for (CalendarWrappers.DailyLogCount dc : results) {
      totalCount += dc.totalCount;
    }
    System.assertEquals(
      6,
      totalCount,
      'Should match all 6 logs via integration code'
    );
  }

  /**
   * @description Tests correlation ID filter.
   */
  @isTest
  static void testFilterByCorrelationId_ReturnsOnlyMatching() {
    Test.startTest();

    // CRITICAL: Use String.valueOf for ISO format (Date doesn't have format with pattern)
    String fromDate = String.valueOf(Date.today().addDays(-3));
    String toDate = String.valueOf(Date.today());

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      'TODAY-ERROR-1',
      fromDate,
      toDate
    );

    Test.stopTest();

    Integer totalCount = 0;
    for (CalendarWrappers.DailyLogCount dc : results) {
      totalCount += dc.totalCount;
    }
    System.assertEquals(
      1,
      totalCount,
      'Should match exactly 1 log by correlation ID'
    );
  }

  /**
   * @description Tests sorting by date ascending.
   */
  @isTest
  static void testResults_SortedByDateAscending() {
    Test.startTest();

    // CRITICAL: Use String.valueOf for ISO format (Date doesn't have format with pattern)
    String fromDate = String.valueOf(Date.today().addDays(-3));
    String toDate = String.valueOf(Date.today());

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      fromDate,
      toDate
    );

    Test.stopTest();

    // Verify ascending order
    for (Integer i = 1; i < results.size(); i++) {
      System.assert(
        results[i - 1].logDate <= results[i].logDate,
        'Results should be sorted by date ascending'
      );
    }
  }

  /**
   * @description Tests empty result when no logs match filters.
   */
  @isTest
  static void testEmptyResult_WhenNoMatches() {
    Test.startTest();

    // Query for a specific integration code that doesn't exist
    // CRITICAL: Use String.valueOf for ISO format (Date doesn't have format with pattern)
    String fromDate = String.valueOf(Date.today().addDays(-3));
    String toDate = String.valueOf(Date.today());

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      'NONEXISTENT-CODE',
      null,
      fromDate,
      toDate
    );

    Test.stopTest();

    System.assertEquals(
      0,
      results.size(),
      'Should return empty list for non-matching filter'
    );
  }

  /**
   * @description Tests end-of-day boundary - records at late times should be included.
   * This verifies the fix for DateTime comparison where endDateTime = 23:59:59.999.
   */
  @isTest
  static void testEndOfDayBoundary_IncludesLateRecords() {
    Date yesterday = Date.today().addDays(-1);

    // Create a log at 20:00 (evening) on yesterday - avoid midnight edge cases
    Datetime eveningTime = DateTime.newInstance(
      yesterday,
      Time.newInstance(20, 0, 0, 0)
    );

    Integration_Log__c eveningLog = new Integration_Log__c(
      OccurredAt__c = eveningTime,
      ObservationType__c = OBS_SUCCESS,
      Context__c = '{"test": "evening"}',
      IntegrationCode__c = 'TEST-INT',
      CorrelationId__c = 'EVENING-LOG'
    );
    insert eveningLog;

    Test.startTest();

    String queryDate = String.valueOf(yesterday);

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      queryDate,
      queryDate
    );

    Test.stopTest();

    // Setup creates 2 logs for yesterday (PARTIAL_RESPONSE + RETRY_ATTEMPT)
    // Evening log adds 1 SUCCESS log at 20:00
    // Expected: 3 total (2 WARN + 1 SUCCESS)
    CalendarWrappers.DailyLogCount yesterdayCount = findCountByDate(
      results,
      yesterday
    );
    System.assertNotEquals(null, yesterdayCount, 'Yesterday should have data');
    System.assertEquals(
      3,
      yesterdayCount.totalCount,
      'Should have 3 logs: 2 from setup + 1 evening'
    );
    System.assertEquals(
      2,
      yesterdayCount.warningCount,
      'Should have 2 WARN logs from setup'
    );
    System.assertEquals(
      1,
      yesterdayCount.successCount,
      'Should have 1 SUCCESS log (evening)'
    );
  }

  /**
   * @description Tests start-of-day boundary - records at 00:01 should be included.
   */
  @isTest
  static void testStartOfDayBoundary_IncludesEarlyRecords() {
    // Create a log at 00:01 (early in the day)
    Datetime startOfDay = DateTime.newInstance(
      Date.today(),
      Time.newInstance(0, 1, 0, 0)
    );

    Integration_Log__c earlyLog = new Integration_Log__c(
      OccurredAt__c = startOfDay,
      ObservationType__c = OBS_SUCCESS,
      Context__c = '{"test": "start-of-day"}',
      IntegrationCode__c = 'TEST-INT',
      CorrelationId__c = 'EARLY-LOG'
    );
    insert earlyLog;

    Test.startTest();

    // CRITICAL: Use String.valueOf for ISO format (Date doesn't have format with pattern)
    String today = String.valueOf(Date.today());

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      today,
      today
    );

    Test.stopTest();

    // Should include the early log + existing today logs
    System.assertEquals(1, results.size(), 'Should return only today');
    // Original: 2 ERROR + 1 SUCCESS + new early SUCCESS = 4
    System.assertEquals(
      4,
      results[0].totalCount,
      'Should include early-morning record in today count'
    );
  }

  // ==================== TIMEZONE TESTS ====================

  /**
   * @description Tests parseDate with various date string formats.
   * Verifies that Date.newInstance() is used to respect running user's timezone.
   */
  @isTest
  static void testParseDate_HandlesVariousFormats() {
    Date expected = Date.newInstance(2026, 3, 27);

    // Test: Plain date string
    Date result1 = CalendarController.parseDate('2026-03-27', null);
    System.assertEquals(expected, result1, 'Should parse YYYY-MM-DD correctly');

    // Test: Datetime string (extracts date part)
    Date result2 = CalendarController.parseDate(
      '2026-03-27T14:30:00.000Z',
      null
    );
    System.assertEquals(
      expected,
      result2,
      'Should extract date from datetime string'
    );

    // Test: Datetime string with different time
    Date result3 = CalendarController.parseDate('2026-03-27T00:00:00', null);
    System.assertEquals(
      expected,
      result3,
      'Should extract date from midnight datetime'
    );

    // Test: Null input returns default
    Date result4 = CalendarController.parseDate(null, expected);
    System.assertEquals(expected, result4, 'Null should return default');

    // Test: Blank input returns default
    Date result5 = CalendarController.parseDate('  ', expected);
    System.assertEquals(expected, result5, 'Blank should return default');

    // Test: Invalid format returns default
    Date result6 = CalendarController.parseDate('invalid', expected);
    System.assertEquals(expected, result6, 'Invalid should return default');
  }

  /**
   * @description Tests that a single day query returns records for the entire day.
   * Uses a FIXED date (Jan 15) to avoid any Date.today() timezone ambiguity.
   * Uses MIDDAY times to avoid timezone boundary issues.
   */
  @isTest
  static void testSingleDayQuery_ReturnsAllRecordsForThatDay() {
    Date targetDay = Date.newInstance(2026, 1, 15);

    List<Integration_Log__c> logs = new List<Integration_Log__c>{
      createTestLog(
        DateTime.newInstance(targetDay, Time.newInstance(10, 0, 0, 0)),
        OBS_SUCCESS,
        'TZ-MORNING'
      ),
      createTestLog(
        DateTime.newInstance(targetDay, Time.newInstance(14, 0, 0, 0)),
        OBS_ERROR,
        'TZ-NOON'
      ),
      createTestLog(
        DateTime.newInstance(targetDay, Time.newInstance(18, 0, 0, 0)),
        OBS_SUCCESS,
        'TZ-EVENING'
      )
    };
    insert logs;

    Test.startTest();

    String fromDate = String.valueOf(targetDay);
    String toDate = String.valueOf(targetDay);

    List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
      null,
      null,
      null,
      null,
      fromDate,
      toDate
    );

    Test.stopTest();

    Set<Date> resultDates = new Set<Date>();
    for (CalendarWrappers.DailyLogCount dc : results) {
      resultDates.add(dc.logDate);
    }
    System.assertEquals(
      1,
      resultDates.size(),
      'Should group all records into exactly 1 day'
    );
    System.assertEquals(
      1,
      results.size(),
      'Should return exactly 1 day of results'
    );
    System.assertEquals(
      3,
      results[0].totalCount,
      'Should count all 3 logs regardless of time'
    );
    System.assertEquals(1, results[0].errorCount, 'Should have 1 ERROR');
    System.assertEquals(2, results[0].successCount, 'Should have 2 SUCCESS');
  }

  /**
   * @description Tests that end of day (23:59:59) records are included for GMT timezone.
   * Verifies the fix for DateTime boundary handling where records at very late times
   * are correctly attributed to the intended calendar day.
   */
  @isTest
  static void testEndOfDayBoundary_LateEveningRecordsIncluded_GMT() {
    testEndOfDayBoundaryForTimezone('GMT', 'America/Los_Angeles', 2);
  }

  /**
   * @description Tests that end of day (23:59:59) records are included for PST timezone.
   * PST is UTC-8. A record at 23:59 PST = 07:59 next day UTC. It should still show
   * on the previous calendar day in the PST user's view.
   */
  @isTest
  static void testEndOfDayBoundary_LateEveningRecordsIncluded_PST() {
    testEndOfDayBoundaryForTimezone(
      'America/Los_Angeles',
      'America/Los_Angeles',
      1
    );
  }

  /**
   * @description Tests that end of day (23:59:59) records are included for JST timezone.
   * JST is UTC+9. A record at 23:59 JST = 14:59 same day UTC. It should show on the
   * same calendar day in the JST user's view.
   */
  @isTest
  static void testEndOfDayBoundary_LateEveningRecordsIncluded_JST() {
    testEndOfDayBoundaryForTimezone('Asia/Tokyo', 'Asia/Tokyo', 1);
  }

  /**
   * @description Helper method to test end of day boundary for a specific timezone.
   * Creates a test user with the specified timezone, runs as that user, and verifies
   * that records at 23:59:59 are correctly attributed to the target day.
   */
  private static void testEndOfDayBoundaryForTimezone(
    String userTimezone,
    String createTimezone,
    Integer daysAgo
  ) {
    Date targetDay = Date.today().addDays(-daysAgo);

    User testUser = createTimezoneTestUser(userTimezone);

    System.runAs(testUser) {
      Datetime veryLate = DateTime.newInstanceGmt(
        targetDay.year(),
        targetDay.month(),
        targetDay.day(),
        23,
        59,
        59
      );

      String uniqueId = 'VERY-LATE-' + createTimezone; // Store ID

      Integration_Log__c lateLog = new Integration_Log__c(
        OccurredAt__c = veryLate,
        ObservationType__c = OBS_SUCCESS,
        Context__c = '{"test": "very_late", "timezone":"' +
          createTimezone +
          '"}',
        IntegrationCode__c = 'TEST-INT',
        CorrelationId__c = uniqueId
      );
      insert lateLog;

      Test.startTest();

      String queryDate = String.valueOf(targetDay);

      List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
        null,
        null,
        null,
        uniqueId,
        queryDate,
        queryDate
      );

      Test.stopTest();

      System.assertEquals(
        1,
        results.size(),
        'Timezone ' + userTimezone + ': Should return the target day'
      );
      System.assertEquals(
        1,
        results[0].totalCount,
        'Timezone ' + userTimezone + ': Should include the late evening record'
      );
    }
  }

  /**
   * @description Tests that start of day (00:00:00) records are included for GMT timezone.
   */
  @isTest
  static void testStartOfDayBoundary_EarlyMorningRecordsIncluded_GMT() {
    testStartOfDayBoundaryForTimezone('GMT', 'GMT', 3);
  }

  /**
   * @description Tests that start of day (00:00:00) records are included for JST timezone.
   * JST is UTC+9. A record at 00:00 JST = 15:00 previous day UTC. It should still show
   * on the next calendar day in the JST user's view.
   */
  @isTest
  static void testStartOfDayBoundary_EarlyMorningRecordsIncluded_JST() {
    testStartOfDayBoundaryForTimezone('Asia/Tokyo', 'Asia/Tokyo', 2);
  }

  /**
   * @description Helper method to test start of day boundary for a specific timezone.
   */
  private static void testStartOfDayBoundaryForTimezone(
    String userTimezone,
    String createTimezone,
    Integer daysAgo
  ) {
    Date targetDay = Date.today().addDays(-daysAgo);

    User testUser = createTimezoneTestUser(userTimezone);

    System.runAs(testUser) {
      Datetime veryEarly = DateTime.newInstance(
        targetDay,
        Time.newInstance(0, 0, 0, 0)
      );

      String uniqueId = 'VERY-EARLY-' + createTimezone; // Store ID

      Integration_Log__c earlyLog = new Integration_Log__c(
        OccurredAt__c = veryEarly,
        ObservationType__c = OBS_SUCCESS,
        Context__c = '{"test": "very_early", "timezone":"' +
          createTimezone +
          '"}',
        IntegrationCode__c = 'TEST-INT',
        CorrelationId__c = uniqueId
      );
      insert earlyLog;

      Test.startTest();

      String queryDate = String.valueOf(targetDay);

      List<CalendarWrappers.DailyLogCount> results = CalendarController.getDailyLogCounts(
        null,
        null,
        null,
        uniqueId,
        queryDate,
        queryDate
      );

      Test.stopTest();

      System.assertEquals(
        1,
        results.size(),
        'Timezone ' + userTimezone + ': Should return the target day'
      );
      System.assertEquals(
        1,
        results[0].totalCount,
        'Timezone ' + userTimezone + ': Should include the early morning record'
      );
    }
  }

  /**
   * @description Creates a test user with a specific timezone for timezone-aware testing.
   */
  private static User createTimezoneTestUser(String timezoneSidKey) {
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];

    String uniqueAlias = 'tz' + String.valueOf(DateTime.now().millisecond());
    if (uniqueAlias.length() > 8) {
      uniqueAlias = uniqueAlias.substring(0, 8);
    }

    User testUser = new User(
      Alias = uniqueAlias,
      FirstName = 'Test',
      LastName = 'TimezoneUser_' + timezoneSidKey.replace('/', '_'),
      Email = 'timezone.test.' +
        timezoneSidKey.replace('/', '_') +
        '@testorg.com',
      Username = 'timezone.test.' +
        timezoneSidKey.replace('/', '_') +
        '@test' +
        DateTime.now().millisecond() +
        '.com',
      TimeZoneSidKey = timezoneSidKey,
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = p.Id
    );
    insert testUser;
    return testUser;
  }

  // ==================== HELPER METHODS ====================

  /**
   * @description Creates a test log with DateTime for OccurredAt__c.
   */
  private static Integration_Log__c createTestLog(
    Datetime occurredAt,
    String observationType,
    String correlationId
  ) {
    Integration_Log__c log = new Integration_Log__c();
    log.OccurredAt__c = occurredAt;
    log.ObservationType__c = observationType;
    log.Context__c = '{"message": "Test log ' + correlationId + '"}';
    log.IntegrationCode__c = 'TEST-INT';
    log.CorrelationId__c = correlationId;
    return log;
  }

  /**
   * @description Finds a DailyLogCount by date.
   */
  private static CalendarWrappers.DailyLogCount findCountByDate(
    List<CalendarWrappers.DailyLogCount> results,
    Date targetDate
  ) {
    for (CalendarWrappers.DailyLogCount dc : results) {
      if (dc.logDate == targetDate) {
        return dc;
      }
    }
    return null;
  }
}
