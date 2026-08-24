/**
 * @description Trigger handler for Integration_Log__c.
 * Extends IEF_SObjectHandler to support trigger plugins.
 */
public with sharing class IntegrationLogTriggerHandler extends IEF_SObjectHandler {
  /**
   * @description Returns the SObject type this handler processes.
   * @return 'Integration_Log__c'
   */
  public override String getSObjectType() {
    return 'Integration_Log__c';
  }
}
