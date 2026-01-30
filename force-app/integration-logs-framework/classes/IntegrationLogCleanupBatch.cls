/**
 * @description Batch job to clean up old Integration_Log__c records.
 * This class implements both Batchable and Schedulable for easy automation.
 *
 * Usage:
 * System.schedule('IHD Log Cleanup Daily', '0 0 2 * * ?', new IntegrationLogCleanupBatch());
 * or
 * Database.executeBatch(new IntegrationLogCleanupBatch(), 200);
 */
global with sharing class IntegrationLogCleanupBatch implements Database.Batchable<SObject>, Schedulable {
  @TestVisible
  private static Integer retentionDays = 30;

  /**
   * @description Schedulable entry point.
   */
  global void execute(SchedulableContext sc) {
    Database.executeBatch(this, 200);
  }

  /**
   * @description Query for logs older than the retention period.
   */
  global Database.QueryLocator start(Database.BatchableContext bc) {
    DateTime cutoff = DateTime.now().addDays(-retentionDays);
    return Database.getQueryLocator(
      [SELECT Id FROM Integration_Log__c WHERE CreatedDate < :cutoff]
    );
  }

  /**
   * @description Delete the logs in chunks. Uses allOrNone=false for resilience.
   */
  global void execute(
    Database.BatchableContext bc,
    List<Integration_Log__c> scope
  ) {
    if (!scope.isEmpty()) {
      Database.delete(scope, false);
      Database.emptyRecycleBin(scope);
    }
  }

  global void finish(Database.BatchableContext bc) {
    IntegrationEventPublisher.emit(
      'FRAMEWORK_INTERNAL',
      'CLEANUP_BATCH_COMPLETED',
      bc.getJobId(),
      null,
      'Retention policy: ' + retentionDays + ' days.'
    );
  }
}
