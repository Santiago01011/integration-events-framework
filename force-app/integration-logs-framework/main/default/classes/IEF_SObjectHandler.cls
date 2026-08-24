/**
 * @description Abstract base class for trigger handlers with plugin support.
 * Extends this class to create handlers that automatically discover and execute
 * registered trigger plugins via IEF_Plugin__mdt.
 */
public abstract with sharing class IEF_SObjectHandler {
  protected String sobjectType;
  protected IEF_TriggerContext context;

  /**
   * @description Returns the SObject API name this handler processes.
   * Subclasses must override this to return their SObject type.
   * @return The SObject API name (e.g., 'Integration_Log__c')
   */
  public abstract String getSObjectType();

  /**
   * @description Executes the handler with plugin support.
   * Discovers TRIGGER plugins for this SObject and calls each in order.
   * Uses IEF_PluginRegistry.resolve() so failures surface as ORPHAN/FAILED and do not break the host.
   */
  public void execute() {
    this.sobjectType = getSObjectType();
    this.context = new IEF_TriggerContext(
      Trigger.operationType,
      Trigger.new,
      Trigger.old,
      Trigger.oldMap
    );

    List<IEF_Plugin__mdt> plugins = IEF_PluginRegistry.getTriggerConfigs(
      this.sobjectType
    );
    for (IEF_Plugin__mdt pluginConfig : plugins) {
      IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(
        pluginConfig
      );
      if (res.status != 'ACTIVE') {
        continue;
      }
      Object pluginInstance = res.instance;
      if (!(pluginInstance instanceof IEF_TriggerPlugin)) {
        continue;
      }
      try {
        IEF_TriggerPlugin triggerPlugin = (IEF_TriggerPlugin) pluginInstance;
        triggerPlugin.execute(pluginConfig, this.context);
      } catch (Exception e) {
        try {
          IntegrationEventPublisher.emit(
            'FRAMEWORK_INTERNAL',
            'TRIGGER_PLUGIN_ERROR',
            null,
            null,
            pluginConfig.DeveloperName + ': ' + e.getMessage()
          );
        } catch (Exception ignored) {
        }
      }
    }
  }
}
