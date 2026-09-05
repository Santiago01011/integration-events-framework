/**
 * @description Dispatcher utility to enqueue async Action Plugins for newly ingested logs.
 * Bulkified to enqueue chunked Queueables that fan out to all plugin executions,
 * avoiding silent loss when governor queueable limit would be exceeded.
 */
public without sharing class IEF_ActionDispatcher {
  private static final Integer CHUNK_SIZE = 50;
  /**
   * @description Dispatches action plugins matching the given integration log records.
   * @param logs List of newly created Integration_Log__c records.
   */
  public static void dispatch(List<Integration_Log__c> logs) {
    if (logs == null || logs.isEmpty()) {
      return;
    }

    List<IEF_Plugin__mdt> actionConfigs = IEF_PluginRegistry.getConfigs(
      IEF_PluginTypeHelper.toPicklistValue(IEF_PluginType.ACTION_TYPE)
    );

    if (actionConfigs == null || actionConfigs.isEmpty()) {
      return;
    }

    List<Id> validLogIds = new List<Id>();
    for (Integration_Log__c log : logs) {
      if (log != null && log.Id != null) {
        validLogIds.add(log.Id);
      }
    }
    if (validLogIds.isEmpty()) {
      return;
    }

    List<String> enabledPluginNames = new List<String>();
    for (IEF_Plugin__mdt config : actionConfigs) {
      if (config.Enabled__c) {
        enabledPluginNames.add(config.DeveloperName);
      }
    }
    if (enabledPluginNames.isEmpty()) {
      return;
    }

    for (List<Id> chunk : chunkLogIds(validLogIds)) {
      if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
        System.enqueueJob(new IEF_ActionQueueable(chunk, enabledPluginNames));
      } else {
        handleQueueableLimitExceeded(chunk, enabledPluginNames);
      }
    }
  }

  private static List<List<Id>> chunkLogIds(List<Id> logIds) {
    List<List<Id>> chunks = new List<List<Id>>();
    for (Integer i = 0; i < logIds.size(); i += CHUNK_SIZE) {
      Integer chunkEnd = Math.min(i + CHUNK_SIZE, logIds.size());
      List<Id> chunk = new List<Id>();
      for (Integer j = i; j < chunkEnd; j++) {
        chunk.add(logIds[j]);
      }
      chunks.add(chunk);
    }
    return chunks;
  }

  private static void handleQueueableLimitExceeded(
    List<Id> logIds,
    List<String> pluginNames
  ) {
    String pluginList = String.join(pluginNames, ',');
    List<Integration_Log__c> toUpdate = new List<Integration_Log__c>();
    for (Id logId : logIds) {
      toUpdate.add(
        new Integration_Log__c(
          Id = logId,
          Status__c = 'FAILED',
          ErrorMessage__c = ('Queueable limit exceeded - action plugins not dispatched. Plugins: ' +
            pluginList)
            .left(32768),
          LastRetryAt__c = Datetime.now()
        )
      );
    }
    try {
      update as system toUpdate;
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'IEF_ActionDispatcher: Failed to mark logs FAILED on queueable limit: ' +
        e.getMessage()
      );
    }
    try {
      IntegrationEventPublisher.emit(
        'FRAMEWORK_INTERNAL',
        'QUEUEABLE_LIMIT_EXCEEDED',
        null,
        null,
        'Queueable limit exceeded - ' +
          logIds.size() +
          ' logs not dispatched for plugins: ' +
          pluginList
      );
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'IEF_ActionDispatcher: Failed to emit FRAMEWORK_INTERNAL for queueable limit: ' +
        ex.getMessage()
      );
    }
  }
}
