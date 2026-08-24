/**
 * @description Handler for Integration_Log__c record creation from IntegrationEvent__e platform events.
 * Implements the controller pattern to separate trigger logic from business logic.
 * Supports SERVICE plugin hooks, Platform Event retry checkpointing, and Action Plugin dispatch.
 */
public without sharing class IntegrationLogHandler {
  /**
   * @description Handles the 'after insert' logic for IntegrationEvent__e events.
   * Creates Integration_Log__c records with normalized context values.
   * Calls SERVICE plugin hooks before and after DML.
   * Implements retry checkpointing via EventBus.TriggerContext on transient failures.
   * Dispatches asynchronous Action Plugins for persisted records.
   * @param newEvents The list of new platform events from Trigger.new
   */
  public static void handleEvents(List<IntegrationEvent__e> newEvents) {
    if (newEvents == null || newEvents.isEmpty()) {
      return;
    }

    List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();

    for (IntegrationEvent__e event : newEvents) {
      Integration_Log__c log = new Integration_Log__c(
        Context__c = event.Context__c,
        Normalized_Context__c = IntegrationContextService.normalize(
          event.IntegrationCode__c
        ),
        ObservationType__c = event.ObservationType__c,
        IntegrationCode__c = event.IntegrationCode__c,
        CorrelationId__c = event.CorrelationId__c,
        ParentEventId__c = event.ParentEventId__c,
        OccurredAt__c = event.OccurredAt__c,
        Status__c = 'PENDING',
        RetryCount__c = 0,
        MaxRetries__c = 3
      );

      logsToInsert.add(log);
    }

    if (logsToInsert.isEmpty()) {
      return;
    }

    // SERVICE plugin hooks: beforeProcess
    callServicePlugins('beforeProcess', logsToInsert);

    // Database.insert with partial success
    Database.SaveResult[] saveResults = Database.insert(logsToInsert, false);

    // Evaluate results and handle retry/checkpointing if needed
    handleSaveResults(newEvents, saveResults);

    // Filter successfully inserted records for downstream processing
    List<Integration_Log__c> insertedLogs = new List<Integration_Log__c>();
    for (Integration_Log__c log : logsToInsert) {
      if (log.Id != null) {
        insertedLogs.add(log);
      }
    }

    // SERVICE plugin hooks: afterProcess
    callServicePlugins('afterProcess', insertedLogs);

    // Dispatch asynchronous Action Plugins
    IEF_ActionDispatcher.dispatch(insertedLogs);
  }

  /**
   * @description Evaluates SaveResults and manages EventBus retry checkpoints on failure.
   */
  private static void handleSaveResults(
    List<IntegrationEvent__e> events,
    Database.SaveResult[] saveResults
  ) {
    Integer firstFailureIndex = -1;
    String failureMessage = '';

    for (Integer i = 0; i < saveResults.size(); i++) {
      if (!saveResults[i].isSuccess()) {
        if (firstFailureIndex == -1) {
          firstFailureIndex = i;
          List<Database.Error> errors = saveResults[i].getErrors();
          if (errors != null && !errors.isEmpty()) {
            failureMessage = errors[0].getMessage();
          }
        }
        System.debug(
          LoggingLevel.ERROR,
          'IEF: Failed to insert Integration_Log__c for event ' +
            events[i].IntegrationCode__c +
            ' (' +
            events[i].CorrelationId__c +
            '): ' +
            failureMessage
        );
      }
    }

    if (firstFailureIndex != -1) {
      EventBus.TriggerContext ctx;
      try {
        ctx = EventBus.TriggerContext.currentContext();
      } catch (Exception ex) {
        // Can occur when running in direct unit test contexts outside of PE subscriber
      }

      if (ctx != null && ctx.retries < 3) {
        if (
          firstFailureIndex > 0 &&
          String.isNotBlank(events[firstFailureIndex - 1].ReplayId)
        ) {
          ctx.setResumeCheckpoint(events[firstFailureIndex - 1].ReplayId);
        }
        throw new EventBus.RetryableException(
          'IEF: Transient insert failure. Retrying: ' + failureMessage
        );
      }
    }
  }

  /**
   * @description Calls SERVICE plugins for the given hook (beforeProcess or afterProcess).
   * Each plugin is called with try-catch isolation — one broken plugin doesn't affect others.
   * @param hook The hook name ('beforeProcess' or 'afterProcess')
   * @param records The records to pass to the plugins
   */
  private static void callServicePlugins(
    String hook,
    List<Integration_Log__c> records
  ) {
    List<IEF_Plugin__mdt> serviceConfigs = IEF_PluginRegistry.getConfigs(
      IEF_PluginTypeHelper.toPicklistValue(IEF_PluginType.SERVICE_TYPE)
    );
    for (IEF_Plugin__mdt config : serviceConfigs) {
      Object pluginInstance = IEF_PluginRegistry.getInstance(config);
      if (
        pluginInstance == null || !(pluginInstance instanceof IEF_ServicePlugin)
      ) {
        continue;
      }
      try {
        IEF_ServicePlugin servicePlugin = (IEF_ServicePlugin) pluginInstance;
        if (hook == 'beforeProcess') {
          servicePlugin.beforeProcess(config, records);
        } else if (hook == 'afterProcess') {
          servicePlugin.afterProcess(config, records);
        }
      } catch (Exception e) {
        System.debug(
          LoggingLevel.ERROR,
          'IntegrationLogHandler: SERVICE plugin ' +
            config.DeveloperName +
            ' threw exception on ' +
            hook +
            ': ' +
            e.getMessage()
        );
      }
    }
  }
}
