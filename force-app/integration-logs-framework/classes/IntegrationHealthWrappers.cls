/**
 * @description Wrapper classes for the Integration Health Dashboard.
 */
public class IntegrationHealthWrappers {
  public class IntegrationLogPage {
    @AuraEnabled
    public List<Integration_Log__c> records { get; set; }
    @AuraEnabled
    public KeysetToken nextKey { get; set; }
    @AuraEnabled
    public Boolean hasMore { get; set; }

    @AuraEnabled
    public Map<String, String> typeToSeverity { get; set; }

    public IntegrationLogPage() {
      this.records = new List<Integration_Log__c>();
      this.typeToSeverity = new Map<String, String>();
    }
  }

  public class KeysetToken {
    @AuraEnabled
    public Datetime lastOccurred { get; set; }
    @AuraEnabled
    public Id lastId { get; set; }

    public KeysetToken() {
    }
    public KeysetToken(Datetime lastOccurred, Id lastId) {
      this.lastOccurred = lastOccurred;
      this.lastId = lastId;
    }
  }

  public class LogDetailWrapper {
    @AuraEnabled
    public Integration_Log__c record { get; set; }
    @AuraEnabled
    public String severity { get; set; }
  }

  public class IntegrationSummary {
    @AuraEnabled
    public String integrationCode { get; set; }
    @AuraEnabled
    public String displayName { get; set; }
    @AuraEnabled
    public String groupName { get; set; }
    @AuraEnabled
    public String transport { get; set; }
    @AuraEnabled
    public String direction { get; set; }
    @AuraEnabled
    public Integer totalEvents { get; set; }
    @AuraEnabled
    public Integer successCount { get; set; }
    @AuraEnabled
    public Integer errorCount { get; set; }
    @AuraEnabled
    public Datetime lastOccurredAt { get; set; }
    @AuraEnabled
    public Boolean isRegistered { get; set; }
    @AuraEnabled
    public List<String> componentLabels { get; set; }

    public IntegrationSummary() {
      this.totalEvents = 0;
      this.successCount = 0;
      this.errorCount = 0;
      this.isRegistered = false;
      this.componentLabels = new List<String>();
    }
  }

  public class RegistryEntry implements Comparable {
    @AuraEnabled
    public String integrationCode { get; set; }
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String groupName { get; set; }
    @AuraEnabled
    public String direction { get; set; }
    @AuraEnabled
    public String transport { get; set; }
    @AuraEnabled
    public Boolean isRegistered { get; set; }
    @AuraEnabled
    public Boolean isEnabled { get; set; }
    @AuraEnabled
    public Integer eventCount { get; set; }

    public Integer compareTo(Object compareTo) {
      RegistryEntry other = (RegistryEntry) compareTo;
      if (this.integrationCode == null)
        return -1;
      if (other.integrationCode == null)
        return 1;
      return this.integrationCode.compareTo(other.integrationCode);
    }
  }

  public class FilterOptions {
    @AuraEnabled
    public List<String> observationTypes { get; set; }
    @AuraEnabled
    public List<String> integrationCodes { get; set; }

    public FilterOptions() {
      this.observationTypes = new List<String>();
      this.integrationCodes = new List<String>();
    }
  }
}
