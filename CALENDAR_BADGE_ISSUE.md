# Calendar Plugin - Badge Display Not Working

## Issue Summary

The calendar plugin renders correctly but **no badges appear** on days with integration logs, even though data exists in Salesforce.

## Expected Behavior

- Each calendar day cell should show a badge with the count of logs
- Badge should be color-coded by severity (red for errors, yellow for warnings, etc.)
- For March 27, 2026, should display 5 error badges (INTERNAL_CONTROLLER_ERROR records exist)

## Current Behavior

- Calendar renders with empty data
- Console shows: `Apex result: []` (empty array)
- All lookups show empty Proxy objects
- No badges displayed

## What We've Tried & Fixed ✅

### 1. LWC Reactivity Issues

**Fixed:** Data wasn't flowing from parent to child components

- Added `@track` decorator to `_dailyCountsMap` in calendarGrid.js
- Changed to spread syntax `{...countsMap}` to create new object references
- Added console logging throughout the data pipeline

**Files Changed:**

- `calendarCardImpl.js` - Uses `{...countsMap}` for reactivity
- `calendarGrid.js` - Added getter/setter with `@track`
- `dayCell.js` - Added getter/setter with `@track`

### 2. SOQL Query Issues

**Fixed:** Invalid SOQL date functions

- ❌ `CALENDAR_DAY` - doesn't exist in SOQL
- ❌ `MONTH` - doesn't exist in SOQL
- ❌ `YEAR` - doesn't exist in SOQL
- ✅ `DAY_IN_MONTH(OccurredAt__c)` - returns Integer
- ✅ `CALENDAR_MONTH(OccurredAt__c)` - returns Date object (must extract `.month()`)
- ✅ `CALENDAR_YEAR(OccurredAt__c)` - returns Date object (must extract `.year()`)

**Updated Query:**

```java
SELECT
  DAY_IN_MONTH(OccurredAt__c) LogDay,
  CALENDAR_MONTH(OccurredAt__c) LogMonth,
  CALENDAR_YEAR(OccurredAt__c) LogYear,
  ObservationType__c ObservationType,
  COUNT(Id) DayCount
FROM Integration_Log__c
WHERE OccurredAt__c >= :startDate AND OccurredAt__c <= :endDate
GROUP BY DAY_IN_MONTH(OccurredAt__c), CALENDAR_MONTH(OccurredAt__c), CALENDAR_YEAR(OccurredAt__c), ObservationType__c
ORDER BY CALENDAR_YEAR(OccurredAt__c) ASC, CALENDAR_MONTH(OccurredAt__c) ASC, DAY_IN_MONTH(OccurredAt__c) ASC
```

**Result Processing:**

```java
Integer logDay = (Integer) result.get('LogDay');
Date logMonthDate = (Date) result.get('LogMonth'); // Returns Date, not Integer
Date logYearDate = (Date) result.get('LogYear');   // Returns Date, not Integer
Integer logMonth = logMonthDate.month();
Integer logYear = logYearDate.year();
Date logDate = Date.newInstance(logYear, logMonth, logDay);
```

### 3. Severity Mapping

**Fixed:** Hardcoded severity mapping didn't match actual observation types

- Query `idhIntegration_Evaluation_Rule__mdt` metadata for type-to-severity mapping
- Map `INTERNAL_CONTROLLER_ERROR` → `ERROR` (via metadata lookup)
- Framework pattern: observation types are mapped via custom metadata

**Code Added:**

```java
Map<String, String> typeToSeverity = new Map<String, String>();
for (idhIntegration_Evaluation_Rule__mdt rule : [
  SELECT ObservationType__c, Severity__c
  FROM idhIntegration_Evaluation_Rule__mdt
]) {
  typeToSeverity.put(rule.ObservationType__c.toUpperCase(), rule.Severity__c);
}
```

## What's Still Broken ❌

### Issue: Apex Returns Empty Results

**Evidence:**

- Console shows: `Apex result: []`
- `Setting dailyCountsMap with keys: []`
- All date lookups: `Looking up: 2026-03-27 in Proxy(Object) {}`

**Test Data Exists:**

```
5 records with:
- ObservationType__c: INTERNAL_CONTROLLER_ERROR
- OccurredAt__c: 2026-03-27 (various times)
```

### Possible Causes:

#### 1. Date Range Mismatch

The calendar is showing March 2026, but the query might be using different dates.

**Check:** Add debug logging to verify start/end dates:

```java
System.debug('Parsed dates - start: ' + startDate + ', end: ' + endDate);
System.debug('Calendar query: ' + baseQuery);
```

#### 2. SOQL Group By Issues

Using aggregate functions in SELECT but grouping by non-aggregated field order might cause issues.

**Alternative Query Approach:**
Don't use aggregate functions for day/month/year - instead:

1. Query individual log records
2. Group in Apex code by extracting date components
3. More reliable but less efficient

```java
// Alternative: Get raw records, aggregate in Apex
List<Integration_Log__c> logs = [
  SELECT OccurredAt__c, ObservationType__c
  FROM Integration_Log__c
  WHERE OccurredAt__c >= :startDate AND OccurredAt__c <= :endDate
];

// Then group in code
Map<String, DailyLogCount> countsByDate = new Map<String, DailyLogCount>();
for (Integration_Log__c log : logs) {
  String dateKey = log.OccurredAt__c.format('yyyy-MM-dd');
  // ... aggregate counts
}
```

#### 3. Field API Names

Verify field names match exactly:

- `OccurredAt__c` (check underscores)
- `ObservationType__c`
- `IntegrationCode__c`
- `CorrelationId__c`
- `Context__c`

#### 4. DateTime vs Date

The query uses `OccurrenceAt__c` (DateTime) but calendar works with Dates. Time component might be causing issues.

**Check:** Ensure startDate/endDate include full day ranges:

```java
// Start of day
DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
// End of day
DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 999));
```

## Console Debug Output Pattern

When working, you should see:

```
Parsed dates - start: 2026-03-01, end: 2026-03-31
Calendar query: SELECT ...
Query returned 1 rows
Row: {LogDay=27, LogMonth=2026-03-01, LogYear=2026-01-01, ObservationType=INTERNAL_CONTROLLER_ERROR, DayCount=5}
Setting dailyCountsMap with keys: ["2026-03-27"]
calendarGrid setter received: object ["2026-03-27"]
Looking up: 2026-03-27 in {"2026-03-27": {...}}
```

## Files Involved

### Apex

- `force-app/ihd-plugin-calendar/main/default/classes/CalendarController.cls`
- `force-app/ihd-plugin-calendar/main/default/classes/CalendarWrappers.cls`

### LWC

- `force-app/ihd-plugin-calendar/main/default/lwc/calendarCardImpl/`
- `force-app/ihd-plugin-calendar/main/default/lwc/calendarGrid/`
- `force-app/ihd-plugin-calendar/main/default/lwc/dayCell/`

### Metadata (for severity mapping)

- `idhIntegration_Evaluation_Rule__mdt`

## Next Steps / Debugging Plan

1. **Verify Query Works in Developer Console:**

   ```apex
   Date startDate = Date.newInstance(2026, 3, 1);
   Date endDate = Date.newInstance(2026, 3, 31);

   String query = 'SELECT DAY_IN_MONTH(OccurredAt__c) LogDay, CALENDAR_MONTH(OccurredAt__c) LogMonth, CALENDAR_YEAR(OccurredAt__c) LogYear, ObservationType__c, COUNT(Id) DayCount FROM Integration_Log__c WHERE OccurredAt__c >= :startDate AND OccurredAt__c <= :endDate GROUP BY DAY_IN_MONTH(OccurredAt__c), CALENDAR_MONTH(OccurredAt__c), CALENDAR_YEAR(OccurredAt__c), ObservationType__c ORDER BY CALENDAR_YEAR(OccurredAt__c) ASC, CALENDAR_MONTH(OccurredAt__c) ASC, DAY_IN_MONTH(OccurredAt__c) ASC';

   List<AggregateResult> results = Database.query(query);
   System.debug('Results: ' + results);
   ```

2. **Check Actual Data:**

   ```apex
   // Verify logs exist
   SELECT ObservationType__c, OccurredAt__c
   FROM Integration_Log__c
   WHERE CALENDAR_MONTH(OccurredAt__c) = 3
   AND CALENDAR_YEAR(OccurredAt__c) = 2026
   ```

3. **Try Alternative Approach:**
   If aggregate query continues to fail, query individual records and aggregate in Apex.

4. **Check Metadata:**
   ```apex
   SELECT ObservationType__c, Severity__c
   FROM idhIntegration_Evaluation_Rule__mdt
   WHERE ObservationType__c = 'INTERNAL_CONTROLLER_ERROR'
   ```

## Branch

`feature/calendar-update`

## Related Memory

- Session: `sdd-session-calendar-initial-impl`
- Learnings saved in Engram about SOQL date functions and LWC reactivity
