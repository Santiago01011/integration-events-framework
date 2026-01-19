@IsTest
private class IntegrationLogCleanupBatchTest {
  @TestSetup
  static void setup() {
    List<Integration_Log__c> logs = new List<Integration_Log__c>();

    for (Integer i = 0; i < 10; i++) {
      logs.add(
        new Integration_Log__c(
          IntegrationCode__c = 'TEST_OLD',
          ObservationType__c = 'TEST'
        )
      );
    }

    for (Integer i = 0; i < 5; i++) {
      logs.add(
        new Integration_Log__c(
          IntegrationCode__c = 'TEST_NEW',
          ObservationType__c = 'TEST'
        )
      );
    }

    insert logs;
  }
  /**
   * Test that the batch cleanup works as expected
   */
  @IsTest
  static void testBatchCleanup() {
    IntegrationLogCleanupBatch.retentionDays = -1;

    Test.startTest();
    IntegrationLogCleanupBatch batch = new IntegrationLogCleanupBatch();
    Id batchId = Database.executeBatch(batch);
    Test.stopTest();

    Integer logCount = [SELECT COUNT() FROM Integration_Log__c];
    System.assertEquals(
      1,
      logCount,
      'Only the cleanup completion log should remain'
    );
  }

  @IsTest
  static void testBatchCleanupRetention() {
    // Set retention high so nothing is deleted
    IntegrationLogCleanupBatch.retentionDays = 30;

    Test.startTest();
    IntegrationLogCleanupBatch batch = new IntegrationLogCleanupBatch();
    Database.executeBatch(batch);
    Test.stopTest();

    Integer logCount = [SELECT COUNT() FROM Integration_Log__c];
    // We expect 15 (original) + 1 (cleanup completion log) = 16
    System.assertEquals(
      16,
      logCount,
      'Original logs + cleanup completion log should exist'
    );
  }

  @IsTest
  static void testScheduling() {
    Test.startTest();
    String cron = '0 0 2 * * ?';
    String jobId = System.schedule(
      'Test Log Cleanup',
      cron,
      new IntegrationLogCleanupBatch()
    );
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'Job should be scheduled');

    CronTrigger ct = [
      SELECT Id, CronExpression
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.assertEquals(cron, ct.CronExpression);
  }
}
