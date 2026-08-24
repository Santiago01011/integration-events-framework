/**
 * @description Dispatcher utility to enqueue async Action Plugins for newly ingested logs.
 */
public without sharing class IEF_ActionDispatcher {
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

    for (Integration_Log__c log : logs) {
      if (log == null || log.Id == null) {
        continue;
      }
      for (IEF_Plugin__mdt config : actionConfigs) {
        if (!config.Enabled__c) {
          continue;
        }
        if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
          System.enqueueJob(
            new IEF_ActionQueueable(log.Id, config.DeveloperName)
          );
        }
      }
    }
  }
}
