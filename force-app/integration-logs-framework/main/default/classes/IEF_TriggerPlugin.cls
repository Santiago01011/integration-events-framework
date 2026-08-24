/**
 * @description Interface for trigger plugin implementations.
 * Plugins implementing this interface can hook into Integration_Log__c trigger events.
 */
public interface IEF_TriggerPlugin {
  /**
   * @description Executes the plugin with the given configuration and trigger context.
   * @param config The plugin's IEF_Plugin__mdt record
   * @param context The trigger context containing operation type, new/old records
   */
  void execute(IEF_Plugin__mdt config, IEF_TriggerContext context);
}
