/**
 * @description Trigger on Integration_Log__c for plugin extensibility.
 * Delegates all logic to IntegrationLogTriggerHandler.
 */
trigger IntegrationLogTrigger on Integration_Log__c(
  before insert,
  before update,
  before delete,
  after insert,
  after update,
  after delete
) {
  IntegrationLogTriggerHandler handler = new IntegrationLogTriggerHandler();
  handler.execute();
}
