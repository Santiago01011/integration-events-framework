/**
 * @description Helper for IEF_PluginType enum to map enum values to
 * IEF_Plugin__mdt.PluginType__c picklist strings. Apex enums cannot use
 * reserved keywords like TRIGGER, so enum values use _TYPE suffix and
 * this helper maps back to the picklist value.
 */
public with sharing class IEF_PluginTypeHelper {
  private static final Map<IEF_PluginType, String> PICKLIST_BY_TYPE = new Map<IEF_PluginType, String>{
    IEF_PluginType.TRIGGER_TYPE => 'TRIGGER',
    IEF_PluginType.SERVICE_TYPE => 'SERVICE',
    IEF_PluginType.FIELD_TYPE => 'FIELD',
    IEF_PluginType.CARD_TYPE => 'CARD'
  };

  private static final Map<String, IEF_PluginType> TYPE_BY_PICKLIST = new Map<String, IEF_PluginType>();

  static {
    for (IEF_PluginType pt : PICKLIST_BY_TYPE.keySet()) {
      TYPE_BY_PICKLIST.put(PICKLIST_BY_TYPE.get(pt), pt);
    }
  }

  /**
   * @description Maps an enum value to its CMDT picklist string.
   * @param pt The plugin type enum
   * @return Picklist string (e.g. 'TRIGGER') or null if null input
   */
  public static String toPicklistValue(IEF_PluginType pt) {
    if (pt == null) {
      return null;
    }
    return PICKLIST_BY_TYPE.get(pt);
  }

  /**
   * @description Maps a picklist string to its enum value.
   * @param picklistValue The PluginType__c string
   * @return Corresponding enum or null if blank/unknown
   */
  public static IEF_PluginType fromPicklistValue(String picklistValue) {
    if (String.isBlank(picklistValue)) {
      return null;
    }
    return TYPE_BY_PICKLIST.get(picklistValue.trim().toUpperCase());
  }
}
