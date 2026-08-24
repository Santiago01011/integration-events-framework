/**
 * @description Enum for plugin types. Replaces hardcoded string literals (C11).
 * Values correspond to IHD_Plugin__mdt.PluginType__c picklist values.
 */
public enum IHD_PluginType {
  TRIGGER,
  SERVICE,
  FIELD,
  CARD
}
