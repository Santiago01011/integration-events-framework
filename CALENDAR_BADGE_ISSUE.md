# Calendar Plugin - Badge Display Issue (RESOLVED)

## Issue Summary

The calendar plugin was not displaying badges because SOQL queries returned empty results when comparing DateTime fields with Date parameters.

## Root Cause

**DateTime vs Date Comparison in SOQL:**

The `OccurredAt__c` field is a **DateTime** field, but the controller was comparing it with **Date** parameters. When SOQL compares:

- `WHERE OccurredAt__c >= :startDate AND OccurredAt__c <= :endDate`
- Where `startDate` and `endDate` are Date objects

Salesforce implicitly converts Date to DateTime at **midnight (00:00:00)**. This means:

- Records on `endDate` with time > 00:00:00 were **EXCLUDED**
- A log at `2026-03-27T10:30:00` does NOT match `<= 2026-03-27T00:00:00`

## Solution

Convert Date range to DateTime with full day coverage:

```java
DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 999));
```

Then use these DateTime values in the SOQL query:

```java
WHERE OccurredAt__c >= :startDateTime AND OccurredAt__c <= :endDateTime
```

## Changes Made

### CalendarController.cls

- Removed all `System.debug()` statements (not allowed in production)
- Added DateTime conversion for proper SOQL comparison
- Used `IntegrationEventPublisher.handleControllerError(e)` for error handling
- Followed codebase conventions from IntegrationHealthController

### CalendarControllerTest.cls

- Rewrote tests to use **DateTime** for `OccurredAt__c` (not Date)
- Added boundary tests for end-of-day and start-of-day records
- Used `@TestSetup` for test data creation
- Tests verify records at various times on same day are all included

### LWC Files

- Removed all `console.log()` debug statements

## Key Learnings

1. **DateTime vs Date in SOQL**: When comparing DateTime fields with Date variables, always convert to DateTime with explicit time components.

2. **Test Data Must Match Field Types**: Tests were using `Date` for `OccurredAt__c` which hides the bug. Real data has time components, tests should too.

3. **No Debug in Production**: Follow AGENTS.md - no `System.debug()` in Apex, no `console.log()` in LWC for production code.

## Files Changed

- `force-app/ihd-plugin-calendar/main/default/classes/CalendarController.cls`
- `force-app/ihd-plugin-calendar/main/default/classes/CalendarControllerTest.cls`
- `force-app/ihd-plugin-calendar/main/default/lwc/calendarCardImpl/calendarCardImpl.js`
- `force-app/ihd-plugin-calendar/main/default/lwc/calendarGrid/calendarGrid.js`
