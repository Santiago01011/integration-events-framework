/**
 * @description Wrapper classes for the Integration Health Dashboard.
 */
public class IntegrationHealthWrappers {
  public class IntegrationLogPage {
    @AuraEnabled
    public List<Integration_Log__c> records { get; set; }
    @AuraEnabled
    public Boolean hasMore { get; set; }

    @AuraEnabled
    public Map<String, String> typeToSeverity { get; set; }

    @AuraEnabled
    public String lastOccurredAt { get; set; }
    @AuraEnabled
    public Id lastId { get; set; }

    public IntegrationLogPage() {
      this.records = new List<Integration_Log__c>();
      this.typeToSeverity = new Map<String, String>();
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

  /**
   * @description Represents a severity level with its event count and percentage.
   */
  public class SeverityCountEntry {
    @AuraEnabled
    public String severity { get; set; }
    @AuraEnabled
    public Integer count { get; set; }
    @AuraEnabled
    public Decimal percentage { get; set; }

    public SeverityCountEntry() {
      this.count = 0;
      this.percentage = 0;
    }
  }

  /**
   * @description Represents an integration ranked by error count with trend indicator.
   */
  public class TopErrorIntegration {
    @AuraEnabled
    public String integrationCode { get; set; }
    @AuraEnabled
    public String displayName { get; set; }
    @AuraEnabled
    public Integer errorCount { get; set; }
    @AuraEnabled
    public Integer totalEvents { get; set; }
    @AuraEnabled
    public String trend { get; set; }

    public TopErrorIntegration() {
      this.errorCount = 0;
      this.totalEvents = 0;
      this.trend = 'flat';
    }
  }

  /**
   * @description Container for hourly trend data with direction and delta.
   */
  public class HourlyTrendResult {
    @AuraEnabled
    public List<TrendPoint> points { get; set; }
    @AuraEnabled
    public String direction { get; set; }
    @AuraEnabled
    public Decimal delta { get; set; }

    public HourlyTrendResult() {
      this.points = new List<TrendPoint>();
      this.direction = 'flat';
      this.delta = 0;
    }
  }

  /**
   * @description A single data point in the hourly trend sparkline.
   */
  public class TrendPoint {
    @AuraEnabled
    public String hour { get; set; }
    @AuraEnabled
    public Integer errors { get; set; }
    @AuraEnabled
    public Integer total { get; set; }

    public TrendPoint() {
      this.errors = 0;
      this.total = 0;
    }
  }

  /**
   * @description Wrapper for plugin card information passed to the LWC layer.
   * @param label Human-readable label for placeholder rendering when provider is unavailable.
   * @param reason Optional human-readable reason when card cannot render (e.g. missing provider, version mismatch).
   */
  public class PluginInfo {
    @AuraEnabled
    public String developerName { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public String componentName { get; set; }
    @AuraEnabled
    public Integer order { get; set; }
    @AuraEnabled
    public String cardLocation { get; set; }
    @AuraEnabled
    public Object data { get; set; }
    @AuraEnabled
    public Integer gridSpan { get; set; }
    @AuraEnabled
    public String reason { get; set; }
  }

  /**
   * @description Represents a registered plugin from IHD_Plugin__mdt for the Admin tab.
   */
  public class PluginRegistryEntry {
    @AuraEnabled
    public String developerName { get; set; }
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String pluginType { get; set; }
    @AuraEnabled
    public Boolean enabled { get; set; }
    @AuraEnabled
    public String description { get; set; }
    @AuraEnabled
    public String apexClassName { get; set; }
    @AuraEnabled
    public String lwcComponentName { get; set; }
    @AuraEnabled
    public Integer displayOrder { get; set; }
  }
}
