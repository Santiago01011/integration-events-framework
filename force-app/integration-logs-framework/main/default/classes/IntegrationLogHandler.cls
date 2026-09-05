/**
 * @description Handler for Integration_Log__c record creation from IntegrationEvent__e platform events.
 * Implements the controller pattern to separate trigger logic from business logic.
 * Supports SERVICE plugin hooks, Platform Event retry checkpointing, and Action Plugin dispatch.
 */
public without sharing class IntegrationLogHandler {
  private static Set<String> emittedServiceSkips;
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
        ReplayId__c = event.ReplayId,
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
   * Handles idempotent duplicate detection (ReplayId__c) and dead-letter creation on retry exhaustion.
   */
  private static void handleSaveResults(
    List<IntegrationEvent__e> events,
    Database.SaveResult[] saveResults
  ) {
    Integer firstFailureIndex = -1;
    String failureMessage = '';
    Boolean hasNonDupFailure = false;

    for (Integer i = 0; i < saveResults.size(); i++) {
      if (!saveResults[i].isSuccess()) {
        List<Database.Error> errors = saveResults[i].getErrors();
        String msg = '';
        System.StatusCode code = null;
        if (errors != null && !errors.isEmpty()) {
          msg = errors[0].getMessage();
          code = errors[0].getStatusCode();
        }
        Boolean isDuplicateReplayId =
          code == System.StatusCode.DUPLICATE_VALUE &&
          (msg != null && msg.contains('ReplayId__c'));

        if (isDuplicateReplayId) {
          System.debug(
            LoggingLevel.INFO,
            'IEF: Duplicate ReplayId__c ignored idempotently for event ' +
              events[i].IntegrationCode__c +
              ' (' +
              events[i].CorrelationId__c +
              ') ReplayId=' +
              events[i].ReplayId
          );
          continue;
        }

        if (firstFailureIndex == -1) {
          firstFailureIndex = i;
          failureMessage = msg;
        }
        hasNonDupFailure = true;
        System.debug(
          LoggingLevel.ERROR,
          'IEF: Failed to insert Integration_Log__c for event ' +
            events[i].IntegrationCode__c +
            ' (' +
            events[i].CorrelationId__c +
            '): ' +
            msg
        );
      }
    }

    if (firstFailureIndex != -1 && hasNonDupFailure) {
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
      } else {
        handleRetryExhaustion(events, saveResults, failureMessage);
      }
    }
  }

  private static void handleRetryExhaustion(
    List<IntegrationEvent__e> events,
    Database.SaveResult[] saveResults,
    String failureMessage
  ) {
    List<Integration_Log__c> deadLetters = new List<Integration_Log__c>();
    for (Integer i = 0; i < saveResults.size(); i++) {
      if (!saveResults[i].isSuccess()) {
        List<Database.Error> errors = saveResults[i].getErrors();
        System.StatusCode code = null;
        String msg = '';
        if (errors != null && !errors.isEmpty()) {
          code = errors[0].getStatusCode();
          msg = errors[0].getMessage();
        }
        Boolean isDup =
          code == System.StatusCode.DUPLICATE_VALUE &&
          (msg != null && msg.contains('ReplayId__c'));
        if (isDup) {
          continue;
        }
        IntegrationEvent__e evt = events[i];
        deadLetters.add(
          new Integration_Log__c(
            IntegrationCode__c = evt.IntegrationCode__c,
            ObservationType__c = evt.ObservationType__c,
            CorrelationId__c = evt.CorrelationId__c,
            ParentEventId__c = evt.ParentEventId__c,
            Context__c = evt.Context__c,
            Normalized_Context__c = IntegrationContextService.normalize(
              evt.IntegrationCode__c
            ),
            OccurredAt__c = evt.OccurredAt__c,
            ReplayId__c = evt.ReplayId != null
              ? evt.ReplayId + '_DLQ_' + i + '_' + System.now().getTime()
              : 'DLQ_' + evt.CorrelationId__c + '_' + i,
            Status__c = 'DEAD_LETTER',
            ErrorMessage__c = ('Ingestion failed after retries exhausted: ' +
              msg)
              .left(32768),
            RetryCount__c = 3,
            MaxRetries__c = 3
          )
        );
      }
    }

    if (!deadLetters.isEmpty()) {
      try {
        Database.SaveResult[] dlResults = Database.insert(deadLetters, false);
        for (Integer j = 0; j < dlResults.size(); j++) {
          if (!dlResults[j].isSuccess()) {
            System.debug(
              LoggingLevel.ERROR,
              'IEF: Failed to create dead-letter for event ' +
                events[j].CorrelationId__c +
                ': ' +
                dlResults[j].getErrors()[0].getMessage()
            );
          }
        }
      } catch (Exception e) {
        System.debug(
          LoggingLevel.ERROR,
          'IEF: Critical failure creating dead-letters: ' + e.getMessage()
        );
      }
      try {
        IntegrationEventPublisher.emit(
          'FRAMEWORK_INTERNAL',
          'INGESTION_DEAD_LETTER',
          null,
          null,
          'Ingestion dead-letter created for ' +
            deadLetters.size() +
            ' events after retry exhaustion: ' +
            failureMessage
        );
      } catch (Exception ex) {
        System.debug(
          LoggingLevel.ERROR,
          'IEF: Failed to emit FRAMEWORK_INTERNAL for dead-letter: ' +
          ex.getMessage()
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
      IEF_PluginRegistry.Resolution resolution = IEF_PluginRegistry.resolve(
        config
      );
      if (resolution.status != 'ACTIVE') {
        if (
          resolution.status != 'SKIPPED_VERSION_MISMATCH' &&
          (emittedServiceSkips == null ||
          !emittedServiceSkips.contains(config.DeveloperName))
        ) {
          if (emittedServiceSkips == null) {
            emittedServiceSkips = new Set<String>();
          }
          emittedServiceSkips.add(config.DeveloperName);
          try {
            IntegrationEventPublisher.emit(
              'FRAMEWORK_INTERNAL',
              'SERVICE_PLUGIN_SKIPPED',
              config.DeveloperName,
              null,
              resolution.reason
            );
          } catch (Exception ignored) {
          }
        }
        continue;
      }
      Object pluginInstance = resolution.instance;
      if (!(pluginInstance instanceof IEF_ServicePlugin)) {
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
