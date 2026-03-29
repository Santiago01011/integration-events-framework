/**
 * @description Controller for the Calendar Plugin.
 * Provides daily log counts grouped by date with severity breakdowns.
 * Queries Integration_Log__c directly via package dependency.
 */
public with sharing class CalendarController {
  /**
   * @description Fetches daily log counts for calendar visualization.
   * Groups logs by calendar day and observation type (severity).
   * @param search Search term for log message filtering
   * @param observationType Filter by observation type (ERROR, WARN, SUCCESS, INFO)
   * @param integrationCode Filter by integration code
   * @param correlationId Filter by correlation ID
   * @param fromOccurredAt Start of date range (ISO format YYYY-MM-DD)
   * @param to_occurredAt End of date range (ISO format YYYY-MM-DD)
   * @return List<DailyLogCount> Aggregated counts per day
   */
  @AuraEnabled(cacheable=true)
  public static List<CalendarWrappers.DailyLogCount> getDailyLogCounts(
    String search,
    String observationType,
    String integrationCode,
    String correlationId,
    String from_occurredAt,
    String to_occurredAt
  ) {
    try {
      // Parse date range (default to last 90 days if not specified)
      Date startDate = parseDate(from_occurredAt, Date.today().addDays(-90));
      Date endDate = parseDate(to_occurredAt, Date.today());
      // CRITICAL: OccurredAt__c is a DateTime field. When comparing DateTime to Date in SOQL,
      // Date is implicitly converted to DateTime at midnight (00:00:00).
      // For the END date, this means records on that day after midnight are EXCLUDED.
      // Solution: Use DateTime range with full day coverage.
      DateTime startDateTime = DateTime.newInstance(
        startDate,
        Time.newInstance(0, 0, 0, 0)
      );
      DateTime endDateTime = DateTime.newInstance(
        endDate.addDays(1),
        Time.newInstance(0, 0, 0, 0)
      );

      // Prepare search pattern for LIKE query
      String searchPattern = String.isNotBlank(search)
        ? '%' + search + '%'
        : null;

      // Query custom metadata for type-to-severity mapping
      Map<String, String> typeToSeverity = getTypeToSeverityMap();

      // Build and execute query
      List<AggregateResult> results = queryDailyLogCounts(
        startDateTime,
        endDateTime,
        searchPattern,
        observationType,
        integrationCode,
        correlationId
      );

      // Transform results into DailyLogCount objects
      return aggregateResults(results, typeToSeverity);
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return new List<CalendarWrappers.DailyLogCount>();
    }
  }

  /**
   * @description Parses a date string to Date object in running user's timezone.
   * IMPORTANT: Date.valueOf() interprets "YYYY-MM-DD" as UTC, not user's timezone.
   * This method manually parses and uses Date.newInstance() which respects user's timezone.
   * @param dateStr ISO date string (YYYY-MM-DD)
   * @param defaultValue Default value if parsing fails
   * @return Parsed Date or default value
   */
  @TestVisible
  private static Date parseDate(String dateStr, Date defaultValue) {
    if (String.isBlank(dateStr)) {
      return defaultValue;
    }
    try {
      // Handle full datetime strings by extracting just the date part
      String datePart = dateStr.split('T')[0];
      List<String> parts = datePart.split('-');
      Integer year = Integer.valueOf(parts[0]);
      Integer month = Integer.valueOf(parts[1]);
      Integer day = Integer.valueOf(parts[2]);
      // Date.newInstance(year, month, day) creates date in running user's timezone
      return Date.newInstance(year, month, day);
    } catch (Exception e) {
      return defaultValue;
    }
  }

  /**
   * @description Returns type-to-severity mapping from custom metadata.
   */
  private static Map<String, String> getTypeToSeverityMap() {
    Map<String, String> typeToSeverity = new Map<String, String>();
    for (idhIntegration_Evaluation_Rule__mdt rule : [
      SELECT ObservationType__c, Severity__c
      FROM idhIntegration_Evaluation_Rule__mdt
      WITH USER_MODE
    ]) {
      typeToSeverity.put(
        rule.ObservationType__c.toUpperCase(),
        rule.Severity__c
      );
    }
    return typeToSeverity;
  }

  /**
   * @description Queries daily log counts with filters.
   */
  private static List<AggregateResult> queryDailyLogCounts(
    DateTime startDateTime,
    DateTime endDateTime,
    String searchPattern,
    String observationType,
    String integrationCode,
    String correlationId
  ) {
    String query =
      'SELECT DAY_ONLY(convertTimezone(OccurredAt__c)) LogDate, ' +
      'ObservationType__c ObservationType, ' +
      'COUNT(Id) DayCount ' +
      'FROM Integration_Log__c ' +
      'WHERE OccurredAt__c >= :startDateTime AND OccurredAt__c < :endDateTime';

    if (String.isNotBlank(searchPattern)) {
      // Note: Cannot search Context__c in aggregate query (Long Text Area not filterable)
      query += ' AND IntegrationCode__c LIKE :searchPattern';
    }

    if (String.isNotBlank(observationType)) {
      query += ' AND ObservationType__c = :observationType';
    }

    if (String.isNotBlank(integrationCode)) {
      query += ' AND IntegrationCode__c = :integrationCode';
    }

    if (String.isNotBlank(correlationId)) {
      query += ' AND CorrelationId__c = :correlationId';
    }

    query +=
      ' GROUP BY DAY_ONLY(convertTimezone(OccurredAt__c)), ObservationType__c ' +
      'ORDER BY DAY_ONLY(convertTimezone(OccurredAt__c)) ASC';

    return Database.query(query);
  }

  /**
   * @description Aggregates query results into DailyLogCount objects.
   */
  private static List<CalendarWrappers.DailyLogCount> aggregateResults(
    List<AggregateResult> results,
    Map<String, String> typeToSeverity
  ) {
    Map<Date, CalendarWrappers.DailyLogCount> countsByDate = new Map<Date, CalendarWrappers.DailyLogCount>();

    for (AggregateResult result : results) {
      Date logDate = (Date) result.get('LogDate');
      String obsType = (String) result.get('ObservationType');
      Integer dayCount = result.get('DayCount') != null
        ? (Integer) result.get('DayCount')
        : 0;

      if (!countsByDate.containsKey(logDate)) {
        CalendarWrappers.DailyLogCount dailyCount = new CalendarWrappers.DailyLogCount();
        dailyCount.logDate = logDate;
        countsByDate.put(logDate, dailyCount);
      }

      CalendarWrappers.DailyLogCount dailyCount = countsByDate.get(logDate);
      dailyCount.totalCount += dayCount;

      // Map observation types to severity counts using metadata
      String severity = typeToSeverity.containsKey(obsType.toUpperCase())
        ? typeToSeverity.get(obsType.toUpperCase())
        : 'INFO';

      if (severity == 'SUCCESS') {
        dailyCount.successCount += dayCount;
      } else if (severity == 'WARN') {
        dailyCount.warningCount += dayCount;
      } else if (severity == 'ERROR' || severity == 'FATAL') {
        dailyCount.errorCount += dayCount;
      } else if (severity == 'INFO') {
        dailyCount.infoCount += dayCount;
      }
    }

    // Return sorted by date
    List<CalendarWrappers.DailyLogCount> result = new List<CalendarWrappers.DailyLogCount>();
    result.addAll(countsByDate.values());
    result.sort(new DateComparator());

    return result;
  }
  /**
   * @description Comparator for sorting DailyLogCount by date.
   */
  public class DateComparator implements Comparator<CalendarWrappers.DailyLogCount> {
    public Integer compare(
      CalendarWrappers.DailyLogCount a,
      CalendarWrappers.DailyLogCount b
    ) {
      if (a.logDate == null && b.logDate == null)
        return 0;
      if (a.logDate == null)
        return 1;
      if (b.logDate == null)
        return -1;
      if (a.logDate < b.logDate)
        return -1;
      if (a.logDate > b.logDate)
        return 1;
      return 0;
    }
  }
}
