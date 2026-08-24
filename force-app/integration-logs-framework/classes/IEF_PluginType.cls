/**
 * @description Enum for plugin types.
 * Values correspond to IEF_Plugin__mdt.PluginType__c picklist values
 * via IEF_PluginTypeHelper.toPicklistValue(). Enum values use _TYPE
 * suffix to avoid reserved keyword TRIGGER.
 */
public enum IEF_PluginType {
  TRIGGER_TYPE,
  SERVICE_TYPE,
  FIELD_TYPE,
  CARD_TYPE
}
