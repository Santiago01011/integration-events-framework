/**
 * @description Core Queueable harness that executes IEF_ActionPlugin implementations.
 * Handles try-catch isolation, retry re-enqueuing, status updates, and attaches
 * IEF_ActionFinalizer for unhandled limit crashes.
 */
public without sharing class IEF_ActionQueueable implements Queueable, Database.AllowsCallouts {
  private Id logId;
  private String pluginDeveloperName;

  public IEF_ActionQueueable(Id logId, String pluginDeveloperName) {
    this.logId = logId;
    this.pluginDeveloperName = pluginDeveloperName;
  }

  public void execute(QueueableContext qc) {
    if (logId == null) {
      return;
    }

    List<Integration_Log__c> logs = [
      SELECT
        Id,
        IntegrationCode__c,
        ObservationType__c,
        CorrelationId__c,
        Context__c,
        Status__c,
        RetryCount__c,
        MaxRetries__c,
        ErrorMessage__c,
        LastRetryAt__c
      FROM Integration_Log__c
      WHERE Id = :logId
      LIMIT 1
    ];

    if (logs.isEmpty()) {
      return;
    }

    Integration_Log__c log = logs[0];
    Integer retries = log.RetryCount__c != null
      ? Integer.valueOf(log.RetryCount__c)
      : 0;
    Integer maxRetries = log.MaxRetries__c != null
      ? Integer.valueOf(log.MaxRetries__c)
      : 3;

    // Attach Finalizer to protect against unhandled limit crashes
    IEF_ActionFinalizer finalizer = new IEF_ActionFinalizer(
      log.Id,
      retries,
      maxRetries,
      pluginDeveloperName
    );
    System.attachFinalizer(finalizer);

    // Resolve plugin instance
    IEF_Plugin__mdt config;
    if (String.isNotBlank(pluginDeveloperName)) {
      List<IEF_Plugin__mdt> actionConfigs = IEF_PluginRegistry.getConfigs(
        IEF_PluginTypeHelper.toPicklistValue(IEF_PluginType.ACTION_TYPE)
      );
      if (actionConfigs != null) {
        for (IEF_Plugin__mdt c : actionConfigs) {
          if (c.DeveloperName == pluginDeveloperName) {
            config = c;
            break;
          }
        }
      }
    }

    if (config == null || !config.Enabled__c) {
      log.Status__c = 'FAILED';
      log.ErrorMessage__c =
        'Action plugin ' +
        pluginDeveloperName +
        ' is not found or inactive.';
      update as system log;
      return;
    }

    IEF_PluginRegistry.Resolution resolution = IEF_PluginRegistry.resolve(
      config
    );
    if (
      resolution == null ||
      resolution.instance == null ||
      !(resolution.instance instanceof IEF_ActionPlugin)
    ) {
      log.Status__c = 'FAILED';
      String errorDetail = resolution != null &&
        String.isNotBlank(resolution.reason)
        ? resolution.reason
        : 'Class ' +
          config.ApexClassName__c +
          ' does not implement IEF_ActionPlugin.';
      log.ErrorMessage__c = errorDetail;
      update as system log;
      return;
    }

    IEF_ActionPlugin actionPlugin = (IEF_ActionPlugin) resolution.instance;
    IEF_ActionContext actionCtx = new IEF_ActionContext(log, config);

    log.Status__c = 'PROCESSING';
    log.LastRetryAt__c = Datetime.now();
    update as system log;

    IEF_ActionResult result;
    try {
      result = actionPlugin.execute(actionCtx);
    } catch (Exception ex) {
      result = IEF_ActionResult.retry(
        'Exception thrown by plugin: ' +
          ex.getMessage() +
          '\n' +
          ex.getStackTraceString()
      );
    }

    if (result == null) {
      result = IEF_ActionResult.fatalFailure('Plugin returned null result');
    }

    if (result.status == IEF_ActionResult.Status.SUCCESS) {
      log.Status__c = 'COMPLETED';
      log.ErrorMessage__c = result.message?.left(32768);
      update as system log;
    } else if (result.status == IEF_ActionResult.Status.RETRY) {
      if (retries < maxRetries) {
        log.RetryCount__c = retries + 1;
        log.Status__c = 'PENDING';
        log.ErrorMessage__c = ('[Retry Attempt ' +
          (retries + 1) +
          '] ' +
          result.message)
          ?.left(32768);
        update as system log;
        if (
          !Test.isRunningTest() &&
          Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()
        ) {
          System.enqueueJob(
            new IEF_ActionQueueable(log.Id, pluginDeveloperName)
          );
        }
      } else {
        log.Status__c = 'DEAD_LETTER';
        log.ErrorMessage__c = ('[Exhausted Retries (' +
          maxRetries +
          ')] ' +
          result.message)
          ?.left(32768);
        update as system log;
      }
    } else {
      // FATAL_FAILURE
      log.Status__c = 'DEAD_LETTER';
      log.ErrorMessage__c = ('[Fatal Failure] ' + result.message)?.left(32768);
      update as system log;
    }
  }
}
