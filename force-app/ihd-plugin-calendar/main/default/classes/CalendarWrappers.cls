/**
 * @description Wrapper classes for the Calendar Plugin.
 * Contains inner classes for daily log counts and related data structures.
 */
public with sharing class CalendarWrappers {
  /**
   * @description Represents aggregated log counts for a single day.
   * Used by CalendarController.getDailyLogCounts() to return calendar data.
   */
  public class DailyLogCount {
    @AuraEnabled
    public Date logDate { get; set; }

    @AuraEnabled
    public Integer totalCount { get; set; }

    @AuraEnabled
    public Integer successCount { get; set; }

    @AuraEnabled
    public Integer warningCount { get; set; }

    @AuraEnabled
    public Integer errorCount { get; set; }

    @AuraEnabled
    public Integer infoCount { get; set; }

    @AuraEnabled
    public List<IntegrationBreakdown> integrations { get; set; }

    public DailyLogCount() {
      this.totalCount = 0;
      this.successCount = 0;
      this.warningCount = 0;
      this.errorCount = 0;
      this.infoCount = 0;
      this.integrations = new List<IntegrationBreakdown>();
    }
  }

  /**
   * @description Represents breakdown of logs by integration code.
   * Used in popovers to show which integrations had activity.
   */
  public class IntegrationBreakdown {
    @AuraEnabled
    public String integrationCode { get; set; }

    @AuraEnabled
    public Integer errorCount { get; set; }

    @AuraEnabled
    public Integer warningCount { get; set; }

    @AuraEnabled
    public Integer successCount { get; set; }

    @AuraEnabled
    public Integer infoCount { get; set; }

    public IntegrationBreakdown() {
      this.integrationCode = '';
      this.errorCount = 0;
      this.warningCount = 0;
      this.successCount = 0;
      this.infoCount = 0;
    }

    public IntegrationBreakdown(String code) {
      this.integrationCode = code;
      this.errorCount = 0;
      this.warningCount = 0;
      this.successCount = 0;
      this.infoCount = 0;
    }

    @AuraEnabled
    public Integer getTotalCount() {
      return this.errorCount +
        this.warningCount +
        this.successCount +
        this.infoCount;
    }
  }
}
