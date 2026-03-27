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
   * @param fromOccurredAt Start of date range (ISO format)
   * @param toOccurredAt End of date range (ISO format)
   * @return List<DailyLogCount> Aggregated counts per day
   */
  @AuraEnabled(cacheable=true)
  public static List<CalendarWrappers.DailyLogCount> getDailyLogCounts(
    String search,
    String observationType,
    String integrationCode,
    String correlationId,
    String fromOccurredAt,
    String toOccurredAt
  ) {
    try {
      // Parse date range (default to last 90 days if not specified)
      Date startDate = parseDate(fromOccurredAt, Date.today().addDays(-90));
      Date endDate = parseDate(toOccurredAt, Date.today());
      System.debug('Parsed dates - start: ' + startDate + ', end: ' + endDate);

      // Prepare search pattern for LIKE query
      String searchPattern = String.isNotBlank(search)
        ? '%' + search + '%'
        : null;

      // Query custom metadata for type-to-severity mapping
      Map<String, String> typeToSeverity = new Map<String, String>();
      for (idhIntegration_Evaluation_Rule__mdt rule : [
        SELECT ObservationType__c, Severity__c
        FROM idhIntegration_Evaluation_Rule__mdt
      ]) {
        typeToSeverity.put(
          rule.ObservationType__c.toUpperCase(),
          rule.Severity__c
        );
      }
      System.debug('Loaded ' + typeToSeverity.size() + ' evaluation rules');

      // Build base query
      String baseQuery = buildBaseQuery(
        searchPattern,
        observationType,
        integrationCode,
        correlationId,
        startDate,
        endDate
      );
      System.debug('Calendar query: ' + baseQuery);
      System.debug('Date range: ' + startDate + ' to ' + endDate);

      // Execute query and aggregate results
      List<AggregateResult> results = Database.query(baseQuery);
      System.debug('Query returned ' + results.size() + ' rows');
      for (AggregateResult ar : results) {
        System.debug('Row: ' + ar);
      }

      // Transform results into DailyLogCount objects
      Map<Date, CalendarWrappers.DailyLogCount> countsByDate = new Map<Date, CalendarWrappers.DailyLogCount>();

      for (AggregateResult result : results) {
        Integer logDay = (Integer) result.get('LogDay');
        // CALENDAR_MONTH and CALENDAR_YEAR return Date objects
        Date logMonthDate = (Date) result.get('LogMonth');
        Date logYearDate = (Date) result.get('LogYear');
        Integer logMonth = logMonthDate.month();
        Integer logYear = logYearDate.year();
        Date logDate = Date.newInstance(logYear, logMonth, logDay);
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
          : 'INFO'; // Default to INFO if not found

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
      for (CalendarWrappers.DailyLogCount count : countsByDate.values()) {
        result.add(count);
      }
      result.sort(new DateComparator());

      return result;
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'CalendarController.getDailyLogCounts error: ' + e.getMessage()
      );
      return new List<CalendarWrappers.DailyLogCount>();
    }
  }

  /**
   * @description Builds the SOQL query with GROUP BY for daily aggregation.
   * @private
   */
  private static String buildBaseQuery(
    String searchPattern,
    String observationType,
    String integrationCode,
    String correlationId,
    Date startDate,
    Date endDate
  ) {
    String query =
      'SELECT DAY_IN_MONTH(OccurredAt__c) LogDay, CALENDAR_MONTH(OccurredAt__c) LogMonth, CALENDAR_YEAR(OccurredAt__c) LogYear, ObservationType__c ObservationType, COUNT(Id) DayCount ' +
      'FROM Integration_Log__c ' +
      'WHERE OccurredAt__c >= :startDate AND OccurredAt__c <= :endDate';

    // Add optional filters
    if (String.isNotBlank(searchPattern)) {
      query += ' AND (Context__c LIKE :searchPattern OR IntegrationCode__c LIKE :searchPattern)';
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
      ' GROUP BY DAY_IN_MONTH(OccurredAt__c), CALENDAR_MONTH(OccurredAt__c), CALENDAR_YEAR(OccurredAt__c), ObservationType__c' +
      ' ORDER BY CALENDAR_YEAR(OccurredAt__c) ASC, CALENDAR_MONTH(OccurredAt__c) ASC, DAY_IN_MONTH(OccurredAt__c) ASC';

    return query;
  }

  /**
   * @description Parses a date string to Date object.
   * @param dateStr ISO date string (YYYY-MM-DD)
   * @param defaultValue Default value if parsing fails
   * @return Parsed Date or default value
   * @private
   */
  private static Date parseDate(String dateStr, Date defaultValue) {
    if (String.isBlank(dateStr)) {
      return defaultValue;
    }
    try {
      return Date.valueOf(dateStr);
    } catch (Exception e) {
      return defaultValue;
    }
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
