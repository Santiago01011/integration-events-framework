/**
 * @description Trigger handler for Integration_Log__c.
 * Extends IHD_SObjectHandler to support trigger plugins.
 */
public with sharing class IntegrationLogTriggerHandler extends IHD_SObjectHandler {
  /**
   * @description Returns the SObject type this handler processes.
   * @return 'Integration_Log__c'
   */
  public override String getSObjectType() {
    return 'Integration_Log__c';
  }
}
