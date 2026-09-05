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
      // Build viewer-local day window and convert bounds to GMT using lossless round-trip to avoid DST/offset errors.
      DateTime localStart = DateTime.newInstance(
        startDate,
        Time.newInstance(0, 0, 0, 0)
      );
      DateTime localEndExclusive = DateTime.newInstance(
        endDate.addDays(1),
        Time.newInstance(0, 0, 0, 0)
      );
      // Convert LOCAL midnights to GMT by subtracting the timezone offset in effect at those instants.
      // Use addSeconds with offsets to avoid valueOfGmt parsing issues in Apex test runtime.
      TimeZone tz = UserInfo.getTimeZone();
      Integer startOffsetSec = Integer.valueOf(
        Math.floor(tz.getOffset(localStart) / 1000)
      );
      Integer endOffsetSec = Integer.valueOf(
        Math.floor(tz.getOffset(localEndExclusive) / 1000)
      );
      DateTime startDateTime = localStart.addSeconds(startOffsetSec);
      DateTime endDateTime = localEndExclusive.addSeconds(endOffsetSec);

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

  /**
   * @description Fetches integration breakdown per day for calendar popovers.
   * Groups logs by date and integration code with severity counts.
   * @param search Search term for log message filtering
   * @param observationType Filter by observation type
   * @param integrationCode Filter by integration code
   * @param correlationId Filter by correlation ID
   * @param fromOccurredAt Start of date range
   * @param toOccurredAt End of date range
   * @return Map<String, List<IntegrationBreakdown>> Integrations per day (key is YYYY-MM-DD string)
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, List<CalendarWrappers.IntegrationBreakdown>> getIntegrationBreakdown(
    String search,
    String observationType,
    String integrationCode,
    String correlationId,
    String fromOccurredAt,
    String toOccurredAt
  ) {
    try {
      Date startDate = parseDate(fromOccurredAt, Date.today().addDays(-90));
      Date endDate = parseDate(toOccurredAt, Date.today());

      // Normalize bounds: viewer-local midnight to GMT for filtering (lossless conversion)
      DateTime localStart = DateTime.newInstance(
        startDate,
        Time.newInstance(0, 0, 0, 0)
      );
      DateTime localEndExclusive = DateTime.newInstance(
        endDate.addDays(1),
        Time.newInstance(0, 0, 0, 0)
      );
      TimeZone tz = UserInfo.getTimeZone();
      Integer startOffsetSec = Integer.valueOf(
        Math.floor(tz.getOffset(localStart) / 1000)
      );
      Integer endOffsetSec = Integer.valueOf(
        Math.floor(tz.getOffset(localEndExclusive) / 1000)
      );
      DateTime startDateTime = localStart.addSeconds(startOffsetSec);
      DateTime endDateTime = localEndExclusive.addSeconds(endOffsetSec);

      String searchPattern = String.isNotBlank(search)
        ? '%' + search + '%'
        : null;

      Map<String, String> typeToSeverity = getTypeToSeverityMap();

      List<AggregateResult> results = queryIntegrationBreakdown(
        startDateTime,
        endDateTime,
        searchPattern,
        observationType,
        integrationCode,
        correlationId
      );

      return aggregateIntegrationBreakdown(results, typeToSeverity);
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return new Map<String, List<CalendarWrappers.IntegrationBreakdown>>();
    }
  }

  private static List<AggregateResult> queryIntegrationBreakdown(
    DateTime startDateTime,
    DateTime endDateTime,
    String searchPattern,
    String observationType,
    String integrationCode,
    String correlationId
  ) {
    String query =
      'SELECT DAY_ONLY(convertTimezone(OccurredAt__c)) LogDate, ' +
      'IntegrationCode__c IntegrationCode, ' +
      'ObservationType__c ObservationType, ' +
      'COUNT(Id) LogCount ' +
      'FROM Integration_Log__c ' +
      'WHERE OccurredAt__c >= :startDateTime AND OccurredAt__c < :endDateTime';

    if (String.isNotBlank(searchPattern)) {
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
      ' GROUP BY DAY_ONLY(convertTimezone(OccurredAt__c)), IntegrationCode__c, ObservationType__c ' +
      'ORDER BY DAY_ONLY(convertTimezone(OccurredAt__c)) ASC, IntegrationCode__c ASC';

    return Database.query(query);
  }

  private static Map<String, List<CalendarWrappers.IntegrationBreakdown>> aggregateIntegrationBreakdown(
    List<AggregateResult> results,
    Map<String, String> typeToSeverity
  ) {
    Map<String, Map<String, CalendarWrappers.IntegrationBreakdown>> integrationsByDate = new Map<String, Map<String, CalendarWrappers.IntegrationBreakdown>>();

    for (AggregateResult result : results) {
      Date logDate = (Date) result.get('LogDate');
      String dateStr = logDate != null ? String.valueOf(logDate) : ''; // YYYY-MM-DD format from Date
      String intCode = (String) result.get('IntegrationCode');
      String obsType = (String) result.get('ObservationType');
      Integer count = result.get('LogCount') != null
        ? (Integer) result.get('LogCount')
        : 0;

      if (String.isBlank(intCode) || String.isBlank(dateStr))
        continue;

      if (!integrationsByDate.containsKey(dateStr)) {
        integrationsByDate.put(
          dateStr,
          new Map<String, CalendarWrappers.IntegrationBreakdown>()
        );
      }

      Map<String, CalendarWrappers.IntegrationBreakdown> dateIntegrations = integrationsByDate.get(
        dateStr
      );

      if (!dateIntegrations.containsKey(intCode)) {
        CalendarWrappers.IntegrationBreakdown breakdown = new CalendarWrappers.IntegrationBreakdown(
          intCode
        );
        dateIntegrations.put(intCode, breakdown);
      }

      CalendarWrappers.IntegrationBreakdown breakdown = dateIntegrations.get(
        intCode
      );

      String severity = typeToSeverity.containsKey(obsType?.toUpperCase())
        ? typeToSeverity.get(obsType.toUpperCase())
        : 'INFO';

      if (severity == 'SUCCESS') {
        breakdown.successCount += count;
      } else if (severity == 'WARN') {
        breakdown.warningCount += count;
      } else if (severity == 'ERROR' || severity == 'FATAL') {
        breakdown.errorCount += count;
      } else if (severity == 'INFO') {
        breakdown.infoCount += count;
      }
    }

    Map<String, List<CalendarWrappers.IntegrationBreakdown>> result = new Map<String, List<CalendarWrappers.IntegrationBreakdown>>();
    for (String d : integrationsByDate.keySet()) {
      List<CalendarWrappers.IntegrationBreakdown> intList = new List<CalendarWrappers.IntegrationBreakdown>();
      intList.addAll(integrationsByDate.get(d).values());
      intList.sort(new IntegrationComparator());
      result.put(d, intList);
    }

    return result;
  }

  public class IntegrationComparator implements Comparator<CalendarWrappers.IntegrationBreakdown> {
    public Integer compare(
      CalendarWrappers.IntegrationBreakdown a,
      CalendarWrappers.IntegrationBreakdown b
    ) {
      Integer aTotal = a.getTotalCount();
      Integer bTotal = b.getTotalCount();
      if (aTotal > bTotal)
        return -1;
      if (aTotal < bTotal)
        return 1;
      return 0;
    }
  }
}
