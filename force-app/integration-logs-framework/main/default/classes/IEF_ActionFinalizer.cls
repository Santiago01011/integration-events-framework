/**
 * @description System.Finalizer implementation attached to IEF_ActionQueueable.
 * Ensures that if a Queueable crashes unexpectedly (unhandled exception, governor limit
 * exhaustion like System.LimitException: Apex CPU time limit exceeded), the log status
 * is updated, the error is recorded, and retry or dead-letter transitions are safely executed.
 */
public without sharing class IEF_ActionFinalizer implements Finalizer {
  private Id logId;
  private Integer retryCount;
  private Integer maxRetries;
  private String pluginDeveloperName;

  public IEF_ActionFinalizer(
    Id logId,
    Integer retryCount,
    Integer maxRetries,
    String pluginDeveloperName
  ) {
    this.logId = logId;
    this.retryCount = retryCount != null ? retryCount : 0;
    this.maxRetries = maxRetries != null ? maxRetries : 3;
    this.pluginDeveloperName = pluginDeveloperName;
  }

  public void execute(FinalizerContext ctx) {
    if (ctx.getResult() == ParentJobResult.SUCCESS) {
      return;
    }

    // Parent job failed unexpectedly (Unhandled exception or limit reached)
    Exception unhandledEx = ctx.getException();
    String errorMsg = unhandledEx != null
      ? unhandledEx.getMessage() + '\n' + unhandledEx.getStackTraceString()
      : 'Queueable job failed with unhandled error (ParentJobResult.UNHANDLED_EXCEPTION)';

    if (String.isNotBlank(pluginDeveloperName)) {
      errorMsg = '[Plugin: ' + pluginDeveloperName + '] ' + errorMsg;
    }

    try {
      Integration_Log__c log = [
        SELECT Id, RetryCount__c, MaxRetries__c, Status__c, ErrorMessage__c
        FROM Integration_Log__c
        WHERE Id = :logId
        LIMIT 1
      ];

      Integer currentRetries = log.RetryCount__c != null
        ? Integer.valueOf(log.RetryCount__c)
        : retryCount;
      Integer limitRetries = log.MaxRetries__c != null
        ? Integer.valueOf(log.MaxRetries__c)
        : maxRetries;

      log.LastRetryAt__c = Datetime.now();
      log.ErrorMessage__c = errorMsg?.left(32768);

      if (currentRetries < limitRetries) {
        log.RetryCount__c = currentRetries + 1;
        log.Status__c = 'PENDING';
      } else {
        log.Status__c = 'DEAD_LETTER';
      }

      update as system log;
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'IEF_ActionFinalizer: Critical failure updating log ' +
          logId +
          ': ' +
          ex.getMessage()
      );
    }
  }
}
