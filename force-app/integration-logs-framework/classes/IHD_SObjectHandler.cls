/**
 * @description Abstract base class for trigger handlers with plugin support.
 * Extends this class to create handlers that automatically discover and execute
 * registered trigger plugins via IHD_Plugin__mdt.
 */
public abstract with sharing class IHD_SObjectHandler {
  protected String sobjectType;
  protected IHD_TriggerContext context;

  /**
   * @description Returns the SObject API name this handler processes.
   * Subclasses must override this to return their SObject type.
   * @return The SObject API name (e.g., 'Integration_Log__c')
   */
  public abstract String getSObjectType();

  /**
   * @description Executes the handler with plugin support.
   * Discovers TRIGGER plugins for this SObject and calls each in order.
   */
  public void execute() {
    this.sobjectType = getSObjectType();
    this.context = new IHD_TriggerContext(
      Trigger.operationType,
      Trigger.new,
      Trigger.old,
      Trigger.oldMap
    );

    List<IHD_Plugin__mdt> plugins = IHD_PluginRegistry.getTriggerConfigs(
      this.sobjectType
    );
    for (IHD_Plugin__mdt pluginConfig : plugins) {
      Object pluginInstance = IHD_PluginRegistry.getInstance(pluginConfig);
      if (pluginInstance == null) {
        continue;
      }
      if (!(pluginInstance instanceof IHD_TriggerPlugin)) {
        System.debug(
          LoggingLevel.WARN,
          'IHD_SObjectHandler: Plugin ' +
            pluginConfig.DeveloperName +
            ' does not implement IHD_TriggerPlugin'
        );
        continue;
      }
      try {
        IHD_TriggerPlugin triggerPlugin = (IHD_TriggerPlugin) pluginInstance;
        triggerPlugin.execute(pluginConfig, this.context);
      } catch (Exception e) {
        System.debug(
          LoggingLevel.ERROR,
          'IHD_SObjectHandler: Plugin ' +
            pluginConfig.DeveloperName +
            ' threw exception: ' +
            e.getMessage() +
            '\n' +
            e.getStackTraceString()
        );
      }
    }
  }
}
