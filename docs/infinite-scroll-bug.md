# Infinite Scroll Bug - Root Cause Analysis & Fix

## Summary

The Integration Health Dashboard's Filters tab was experiencing an infinite scroll bug where the same records would be duplicated infinitely when scrolling. This document describes the root cause and the fix applied.

## Symptoms

- Scrolling past the first page of records caused duplicates to appear
- The `hasMore` flag never became `false`
- Record count grew indefinitely (e.g., 300+ records when only 98 existed)

## Root Cause

**Datetime deserialization failure in Aura/LWC → Apex wrapper classes.**

The pagination mechanism used a `KeysetToken` wrapper class containing:

```apex
public class KeysetToken {
  @AuraEnabled
  public Datetime lastOccurred;
  @AuraEnabled
  public Id lastId;
}
```

When this wrapper was passed from LWC to Apex:

1. **API Version Dependency**: In newer Salesforce orgs (API v59/60+), `Datetime` fields inside wrapper objects are silently deserialized as `null`
2. **Pagination Reset**: The `null` date caused the backend query to reset to page 1
3. **Infinite Loop**: LWC appended page 1 records repeatedly, causing infinite scroll

This is a **known Salesforce platform behavior** where implicit JSON deserialization differs across API versions.

## Solution

Applied the **standard Salesforce infinite loading pattern**: primitive parameters instead of wrapper classes.

### Changes Made

#### Backend (Apex)

1. **Removed `KeysetToken` wrapper class** from `IntegrationHealthWrappers.cls`
2. **Flattened parameters** in `IntegrationHealthController.getRecentLogs`:

   ```apex
   // Before (broken)
   IntegrationHealthWrappers.KeysetToken lastKey

   // After (standard pattern)
   String lastOccurredAtStr,
   Id lastId
   ```

3. **Explicit parsing** in `IntegrationHealthService.getPagedLogs`:
   ```apex
   Datetime lastOccurred = null;
   if (String.isNotBlank(lastOccurredAtStr)) {
     lastOccurred = Datetime.valueOfGmt(
       lastOccurredAtStr.replace('T', ' ').replace('Z', '').substringBefore('.')
     );
   }
   ```
4. **Return primitives** from `IntegrationLogPage`:
   ```apex
   page.lastOccurredAt = lastRecOccurred.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
   page.lastId = lastRecord.Id;
   ```

#### Frontend (LWC)

1. **Store pagination state from response**:
   ```javascript
   this.lastOccurredAt = data.lastOccurredAt;
   this.lastId = data.lastId;
   ```
2. **Pass primitives to Apex** (not extracted from row data):
   ```javascript
   lastOccurredAtStr: this.lastOccurredAt,
   lastId: this.lastId
   ```

## Why This Works

| Approach                     | Behavior                                                           |
| ---------------------------- | ------------------------------------------------------------------ |
| Wrapper with `Datetime`      | Implicit deserialization differs across API versions; often `null` |
| Primitive `String` parameter | Explicit parsing with predictable behavior                         |

Primitive parameters bypass the implicit JSON → Apex coercion that causes the `Datetime` to become `null`.

## References

- [LWC Datatable Infinite Loading](https://developer.salesforce.com/docs/component-library/bundle/lightning-datatable)
- [Apex SOQL Best Practices - Keyset Pagination](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode)

## Files Modified

- `IntegrationHealthWrappers.cls` - Removed `KeysetToken`, added primitives to `IntegrationLogPage`
- `IntegrationHealthController.cls` - Flattened method signature
- `IntegrationHealthService.cls` - Explicit `Datetime` parsing
- `iefDashboard.js` - Store and pass primitive pagination state
- `IntegrationHealthControllerTest.cls` - Updated test calls
- `IntegrationHealthServiceTest.cls` - Updated test calls
