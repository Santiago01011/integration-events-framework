# Sample `idhIntegration_Evaluation_Rule__mdt` row

One row per observation type that should be scored. Observation type matching is case-insensitive EXACT (no wildcards). Severity picklist: `INFO, SUCCESS, WARN, ERROR, FATAL`.

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CustomMetadata
  xmlns="http://soap.sforce.com/2006/04/metadata"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
>
    <label>REVIEW_INGEST_FAILED</label>
    <protected>false</protected>
    <values>
        <field>ObservationType__c</field>
        <value xsi:type="xsd:string">REVIEW_INGEST_FAILED</value>
    </values>
    <values>
        <field>Severity__c</field>
        <value xsi:type="xsd:string">FATAL</value>
    </values>
</CustomMetadata>
```

The core package ships rules for: `BATCH_ERROR, BATCH_PROCESSED, EXCEPTION_THROWN, Internal_IED_error, PARTIAL_RESPONSE, REQUEST_DISPATCHED, RESPONSE_RECEIVED, RETRY_ATTEMPT, Standard_Success, SYNC_COMPLETED, SYNC_STARTED`. Domain-specific types (e.g. `REVIEW_APPROVED`) need their own rows — unregistered types fall through to default handling.

Suggested severity mapping pattern: terminal facts get `SUCCESS`/`INFO`, retries get `WARN`, recoverable failures get `ERROR`, data-loss/integrity failures get `FATAL`.
