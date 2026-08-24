/**
 * @description Handler for Integration_Log__c record creation from IntegrationEvent__e platform events.
 * Implements the controller pattern to separate trigger logic from business logic.
 * Supports SERVICE plugin hooks for before/after processing.
 */
public without sharing class IntegrationLogHandler {
  /**
   * @description Handles the 'after insert' logic for IntegrationEvent__e events.
   * Creates Integration_Log__c records with normalized context values.
   * Calls SERVICE plugin hooks before and after DML.
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
        OccurredAt__c = event.OccurredAt__c
      );

      logsToInsert.add(log);
    }

    if (!logsToInsert.isEmpty()) {
      // SERVICE plugin hooks: beforeProcess
      callServicePlugins('beforeProcess', logsToInsert);

      insert as system logsToInsert;

      // SERVICE plugin hooks: afterProcess
      callServicePlugins('afterProcess', logsToInsert);
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
    List<IHD_Plugin__mdt> serviceConfigs = IHD_PluginRegistry.getConfigs(
      IHD_PluginType.SERVICE.name()
    );
    for (IHD_Plugin__mdt config : serviceConfigs) {
      Object pluginInstance = IHD_PluginRegistry.getInstance(config);
      if (
        pluginInstance == null || !(pluginInstance instanceof IHD_ServicePlugin)
      ) {
        continue;
      }
      try {
        IHD_ServicePlugin servicePlugin = (IHD_ServicePlugin) pluginInstance;
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
