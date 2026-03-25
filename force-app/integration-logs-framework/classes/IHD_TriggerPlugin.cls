/**
 * @description Interface for trigger plugin implementations.
 * Plugins implementing this interface can hook into Integration_Log__c trigger events.
 */
public interface IHD_TriggerPlugin {
  /**
   * @description Executes the plugin with the given configuration and trigger context.
   * @param config The plugin's IHD_Plugin__mdt record
   * @param context The trigger context containing operation type, new/old records
   */
  void execute(IHD_Plugin__mdt config, IHD_TriggerContext context);
}
