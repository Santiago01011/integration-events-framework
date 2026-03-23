/**
 * @description Interface for field extension plugins.
 * Plugins implementing this interface declare custom fields they add to Integration_Log__c.
 */
public interface IHD_FieldPlugin {
  /**
   * @description Returns the set of field API names this plugin declares.
   * @return Set of field API names (e.g., {'Priority__c', 'Category__c'})
   */
  Set<String> getDeclaredFields();

  /**
   * @description Returns the label for a declared field.
   * @param apiName The field API name
   * @return The field label for display
   */
  String getFieldLabel(String apiName);
}
