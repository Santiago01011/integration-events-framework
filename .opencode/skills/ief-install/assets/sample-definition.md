# Sample `idhIntegration_Definition__mdt` row

Create one row per integration code. Metadata API XML (or create via Setup → Custom Metadata Types).

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CustomMetadata
  xmlns="http://soap.sforce.com/2006/04/metadata"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:xsd="http://www.w3.org/2001/XMLSchema"
>
    <label>Reviews B2C</label>
    <protected>false</protected>
    <values>
        <field>IntegrationCode__c</field>
        <value xsi:type="xsd:string">REVIEWS</value>
    </values>
    <values>
        <field>Label__c</field>
        <value xsi:type="xsd:string">Reviews B2C</value>
    </values>
    <values>
        <field>Group__c</field>
        <value xsi:type="xsd:string">Commerce</value>
    </values>
    <values>
        <field>Transport__c</field>
        <value xsi:type="xsd:string">REST</value>
    </values>
    <values>
        <field>Direction__c</field>
        <value xsi:type="xsd:string">Inbound</value>
    </values>
    <values>
        <field>Enabled__c</field>
        <value xsi:type="xsd:boolean">true</value>
    </values>
</CustomMetadata>
```

Field reference (all verified in the IEF package):

| Field                | Type     | Notes                                                                      |
| -------------------- | -------- | -------------------------------------------------------------------------- |
| `IntegrationCode__c` | Text     | Unique code used on every `emit()`; kill-switch key                        |
| `Label__c`           | Text     | Human-readable name                                                        |
| `Group__c`           | Text     | Free grouping (e.g. `Commerce`, `Logistics`)                               |
| `Transport__c`       | Text     | Free (e.g. `REST`, `PLATFORM_EVENT`, `ORDER_PARAMS`)                       |
| `Direction__c`       | Picklist | `Inbound` or `Outbound` only                                               |
| `Enabled__c`         | Checkbox | `false` = kill switch, silences the code everywhere (zero SOQL, no deploy) |
