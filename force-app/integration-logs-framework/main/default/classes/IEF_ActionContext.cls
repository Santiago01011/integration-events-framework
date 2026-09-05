/**
 * @description Context payload passed to IEF_ActionPlugin.execute().
 * Contains the log record, payload context, correlation info, and retry state.
 */
public class IEF_ActionContext {
  public Id logId { get; set; }
  public String integrationCode { get; set; }
  public String observationType { get; set; }
  public String correlationId { get; set; }
  public String payloadContext { get; set; }
  public Integer retryCount { get; set; }
  public Integer maxRetries { get; set; }
  public IEF_Plugin__mdt pluginConfig { get; set; }

  public IEF_ActionContext() {
    this.retryCount = 0;
    this.maxRetries = 3;
  }

  public IEF_ActionContext(Integration_Log__c log, IEF_Plugin__mdt config) {
    if (log != null) {
      this.logId = log.Id;
      this.integrationCode = log.IntegrationCode__c;
      this.observationType = log.ObservationType__c;
      this.correlationId = log.CorrelationId__c;
      this.payloadContext = log.Context__c;
      this.retryCount = log.RetryCount__c != null
        ? Integer.valueOf(log.RetryCount__c)
        : 0;
      this.maxRetries = log.MaxRetries__c != null
        ? Integer.valueOf(log.MaxRetries__c)
        : 3;
    }
    this.pluginConfig = config;
  }
}
