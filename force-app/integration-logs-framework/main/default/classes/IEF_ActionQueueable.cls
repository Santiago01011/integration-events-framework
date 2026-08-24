/**
 * @description Core Queueable harness that executes IEF_ActionPlugin implementations.
 * Handles try-catch isolation, retry re-enqueuing, status updates, and attaches
 * IEF_ActionFinalizer for unhandled limit crashes.
 * Supports bulkified dispatch (List<Id> + List<String>) to avoid silent
 * queueable fan-out loss.
 */
public without sharing class IEF_ActionQueueable implements Queueable, Database.AllowsCallouts {
  private Id logId;
  private String pluginDeveloperName;
  private List<Id> bulkLogIds;
  private List<String> bulkPluginNames;
  private Boolean isBulk = false;

  public IEF_ActionQueueable(Id logId, String pluginDeveloperName) {
    this.logId = logId;
    this.pluginDeveloperName = pluginDeveloperName;
    this.isBulk = false;
  }

  public IEF_ActionQueueable(
    List<Id> logIds,
    List<String> pluginDeveloperNames
  ) {
    this.bulkLogIds = logIds;
    this.bulkPluginNames = pluginDeveloperNames;
    this.isBulk = true;
    this.logId = (logIds != null && !logIds.isEmpty()) ? logIds[0] : null;
    this.pluginDeveloperName = (pluginDeveloperNames != null &&
      !pluginDeveloperNames.isEmpty())
      ? pluginDeveloperNames[0]
      : null;
  }

  public void execute(QueueableContext qc) {
    if (isBulk) {
      executeBulk();
    } else {
      executeSingle(logId, pluginDeveloperName);
    }
  }

  private void executeSingle(Id singleLogId, String singlePluginName) {
    if (singleLogId == null) {
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
      WHERE Id = :singleLogId
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

    IEF_ActionFinalizer finalizer = new IEF_ActionFinalizer(
      log.Id,
      retries,
      maxRetries,
      singlePluginName
    );
    System.attachFinalizer(finalizer);

    Map<String, IEF_Plugin__mdt> configMap = buildConfigMap();
    processPluginForLog(log, singlePluginName, configMap);
  }

  private void executeBulk() {
    if (
      bulkLogIds == null ||
      bulkLogIds.isEmpty() ||
      bulkPluginNames == null ||
      bulkPluginNames.isEmpty()
    ) {
      return;
    }

    Map<Id, Integration_Log__c> logMap = new Map<Id, Integration_Log__c>(
      [
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
        WHERE Id IN :bulkLogIds
      ]
    );

    Map<String, IEF_Plugin__mdt> configMap = buildConfigMap();

    for (Id lid : bulkLogIds) {
      Integration_Log__c log = logMap.get(lid);
      if (log == null) {
        continue;
      }
      for (String pname : bulkPluginNames) {
        try {
          processPluginForLog(log, pname, configMap);
        } catch (Exception ex) {
          System.debug(
            LoggingLevel.ERROR,
            'IEF_ActionQueueable bulk: unhandled exception for log ' +
              lid +
              ' plugin ' +
              pname +
              ': ' +
              ex.getMessage()
          );
          try {
            log.Status__c = 'FAILED';
            log.ErrorMessage__c = ('Bulk processing exception: ' +
              ex.getMessage() +
              '\n' +
              ex.getStackTraceString())
              .left(32768);
            update as system log;
          } catch (Exception updEx) {
            System.debug(
              LoggingLevel.ERROR,
              'IEF_ActionQueueable bulk: failed to update log after exception: ' +
              updEx.getMessage()
            );
          }
        }
      }
    }
  }

  private Map<String, IEF_Plugin__mdt> buildConfigMap() {
    Map<String, IEF_Plugin__mdt> configMap = new Map<String, IEF_Plugin__mdt>();
    List<IEF_Plugin__mdt> actionConfigs = IEF_PluginRegistry.getConfigs(
      IEF_PluginTypeHelper.toPicklistValue(IEF_PluginType.ACTION_TYPE)
    );
    if (actionConfigs != null) {
      for (IEF_Plugin__mdt c : actionConfigs) {
        configMap.put(c.DeveloperName, c);
      }
    }
    return configMap;
  }

  private void processPluginForLog(
    Integration_Log__c log,
    String targetPluginName,
    Map<String, IEF_Plugin__mdt> configMap
  ) {
    Integer retries = log.RetryCount__c != null
      ? Integer.valueOf(log.RetryCount__c)
      : 0;
    Integer maxRetries = log.MaxRetries__c != null
      ? Integer.valueOf(log.MaxRetries__c)
      : 3;

    IEF_Plugin__mdt config = configMap.get(targetPluginName);
    if (String.isBlank(targetPluginName)) {
      config = null;
    }

    if (config == null || !config.Enabled__c) {
      log.Status__c = 'FAILED';
      log.ErrorMessage__c =
        'Action plugin ' +
        targetPluginName +
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
        log.LastRetryAt__c = Datetime.now();
        update as system log;
        Boolean canEnqueue =
          !Test.isRunningTest() &&
          Limits.getQueueableJobs() < Limits.getLimitQueueableJobs();
        if (canEnqueue) {
          System.enqueueJob(new IEF_ActionQueueable(log.Id, targetPluginName));
        } else if (!Test.isRunningTest()) {
          handleRetryQueueableLimitExceeded(log, targetPluginName, retries);
        }
      } else {
        log.Status__c = 'DEAD_LETTER';
        log.ErrorMessage__c = ('[Exhausted Retries (' +
          maxRetries +
          ')] ' +
          result.message)
          ?.left(32768);
        log.LastRetryAt__c = Datetime.now();
        update as system log;
      }
    } else {
      log.Status__c = 'DEAD_LETTER';
      log.ErrorMessage__c = ('[Fatal Failure] ' + result.message)?.left(32768);
      log.LastRetryAt__c = Datetime.now();
      update as system log;
    }
  }

  private void handleRetryQueueableLimitExceeded(
    Integration_Log__c log,
    String pluginName,
    Integer previousRetries
  ) {
    String deferMsg = ' [Retry deferred - queueable limit exceeded, will be picked up by reaper]';
    String currentMsg = log.ErrorMessage__c != null ? log.ErrorMessage__c : '';
    String updatedMsg = (currentMsg + deferMsg).left(32768);
    try {
      Integration_Log__c toUpdate = new Integration_Log__c(
        Id = log.Id,
        ErrorMessage__c = updatedMsg,
        LastRetryAt__c = Datetime.now()
      );
      update as system toUpdate;
      log.ErrorMessage__c = updatedMsg;
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'IEF_ActionQueueable: Failed to persist retry-deferred state: ' +
        e.getMessage()
      );
    }
    try {
      IntegrationEventPublisher.emit(
        'FRAMEWORK_INTERNAL',
        'QUEUEABLE_RETRY_DEFERRED',
        log.CorrelationId__c,
        null,
        'Queueable limit exceeded - retry deferred for log ' +
          log.Id +
          ' plugin ' +
          pluginName +
          ' attempt ' +
          (previousRetries + 1)
      );
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'IEF_ActionQueueable: Failed to emit FRAMEWORK_INTERNAL for retry deferral: ' +
        ex.getMessage()
      );
    }
  }
}
