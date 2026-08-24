/**
 * @description Interface for service plugin implementations.
 * Plugins implementing this interface can hook into service-layer processing.
 */
public interface IEF_ServicePlugin {
  /**
   * @description Called before records are processed.
   * @param config The plugin's IEF_Plugin__mdt record
   * @param records The records about to be processed
   */
  void beforeProcess(IEF_Plugin__mdt config, List<SObject> records);

  /**
   * @description Called after records are processed.
   * @param config The plugin's IEF_Plugin__mdt record
   * @param records The records that were processed
   */
  void afterProcess(IEF_Plugin__mdt config, List<SObject> records);
}
