# IED Best Practices

## 1. Bulk Event Emission (Critical)

### The Problem

Platform Events have an hourly allocation limit. Emitting an event for every single record in a 10,000-record batch will exhaust your limits and fail.

### The Solution: Summary Events

Accumulate results in memory and emit a single event per batch execution (or per chunk).

**❌ Retrieval - BAD Pattern:**

```apex
for (Account a : scope) {
    try {
        update a;
    } catch (Exception e) {
        // DO NOT DO THIS
        IntegrationEventPublisher.emit('ACC_SYNC', 'ERROR', null, null, null);
    }
}
```

**✅ Retrieval - GOOD Pattern:**

```apex
List<String> errors = new List<String>();
for (Account a : scope) {
    try {
        update a;
    } catch (Exception e) {
        errors.add(a.Id + ': ' + e.getMessage());
    }
}

if (!errors.isEmpty()) {
    IntegrationEventPublisher.emit(
        'ACC_SYNC',
        'BATCH_ERRORS',
        jobId,
        null,
        new Map<String, Object>{ 'errorCount' => errors.size(), 'details' => errors }
    );
}
```

---

## 2. Context Data Management

### Keep it Lean

The `Context__c` field is a Long Text Area, but it's not infinite.

- **Do:** Store IDs, critical error messages, and HTTP status codes.
- **Don't:** Dump entire JSON payloads of 5MB into the context. Isolate the relevant failure data.

### Serializable Maps

Always ensure the `Map<String, Object>` you pass to `emit()` is JSON-serializable. Avoid passing complex SObjects without serializing them first.

---

## 3. Log Retention & cleanup

To keep your org limits healthy, you must schedule the cleanup batch.

```apex
// Schedule to run daily at 2 AM
System.schedule('IED Log Cleanup', '0 0 2 * * ?', new IntegrationLogCleanupBatch());
```

- **Default Retention:** 30 days.
- **Customization:** You can modify `IntegrationLogCleanupBatch` to change the query filter if longer retention is needed for compliance. You may also want to persist the logs info to another storage system, tools like `Salesforce Inspector Reloaded` could help you to export the logs.
