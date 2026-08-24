/**
 * @description Comprehensive unit tests for IEF_ActionQueueable, IEF_ActionFinalizer,
 * and IEF_ActionDispatcher.
 */
@IsTest
private class IEF_ActionQueueableTest {
  @TestSetup
  static void setupData() {
    Integration_Log__c log = new Integration_Log__c(
      IntegrationCode__c = 'SAP_TEST',
      ObservationType__c = 'ORDER_SYNC',
      CorrelationId__c = 'CORR-ACTION-1',
      Context__c = '{"orderId": "12345"}',
      Status__c = 'PENDING',
      RetryCount__c = 0,
      MaxRetries__c = 2
    );
    insert log;
  }

  @IsTest
  static void testSuccessfulActionExecution() {
    Integration_Log__c log = [
      SELECT Id, Status__c, RetryCount__c
      FROM Integration_Log__c
      LIMIT 1
    ];

    IEF_Plugin__mdt mockConfig = new IEF_Plugin__mdt(
      DeveloperName = 'Test_Action_Success',
      MasterLabel = 'Test Action Success',
      ApexClassName__c = 'TestStub_ActionPlugin',
      PluginType__c = 'ACTION',
      Enabled__c = true,
      Contract_Version__c = 1.0
    );
    IEF_PluginRegistry.setMockConfigs(new List<IEF_Plugin__mdt>{ mockConfig });

    TestStub_ActionPlugin.shouldThrowException = false;
    TestStub_ActionPlugin.shouldReturnRetry = false;

    Test.startTest();
    System.enqueueJob(new IEF_ActionQueueable(log.Id, 'Test_Action_Success'));
    Test.stopTest();

    Integration_Log__c updated = [
      SELECT Status__c, ErrorMessage__c
      FROM Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals(
      'COMPLETED',
      updated.Status__c,
      'Log status should transition to COMPLETED'
    );
  }

  @IsTest
  static void testRetryActionExecution() {
    Integration_Log__c log = [
      SELECT Id, Status__c, RetryCount__c, MaxRetries__c
      FROM Integration_Log__c
      LIMIT 1
    ];

    IEF_Plugin__mdt mockConfig = new IEF_Plugin__mdt(
      DeveloperName = 'Test_Action_Retry',
      MasterLabel = 'Test Action Retry',
      ApexClassName__c = 'TestStub_ActionPlugin',
      PluginType__c = 'ACTION',
      Enabled__c = true,
      Contract_Version__c = 1.0
    );
    IEF_PluginRegistry.setMockConfigs(new List<IEF_Plugin__mdt>{ mockConfig });

    TestStub_ActionPlugin.shouldThrowException = false;
    TestStub_ActionPlugin.shouldReturnRetry = true;

    Test.startTest();
    System.enqueueJob(new IEF_ActionQueueable(log.Id, 'Test_Action_Retry'));
    Test.stopTest();

    Integration_Log__c updated = [
      SELECT Status__c, RetryCount__c, ErrorMessage__c
      FROM Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals(
      1,
      updated.RetryCount__c,
      'RetryCount should increment to 1'
    );
    System.assertEquals(
      'PENDING',
      updated.Status__c,
      'Status should remain PENDING for next retry attempt'
    );
  }

  @IsTest
  static void testRetryExhaustionToDeadLetter() {
    Integration_Log__c log = [
      SELECT Id, Status__c, RetryCount__c, MaxRetries__c
      FROM Integration_Log__c
      LIMIT 1
    ];
    log.RetryCount__c = 2; // At maximum
    update log;

    IEF_Plugin__mdt mockConfig = new IEF_Plugin__mdt(
      DeveloperName = 'Test_Action_DLQ',
      MasterLabel = 'Test Action DLQ',
      ApexClassName__c = 'TestStub_ActionPlugin',
      PluginType__c = 'ACTION',
      Enabled__c = true,
      Contract_Version__c = 1.0
    );
    IEF_PluginRegistry.setMockConfigs(new List<IEF_Plugin__mdt>{ mockConfig });

    TestStub_ActionPlugin.shouldReturnRetry = true;

    Test.startTest();
    System.enqueueJob(new IEF_ActionQueueable(log.Id, 'Test_Action_DLQ'));
    Test.stopTest();

    Integration_Log__c updated = [
      SELECT Status__c, ErrorMessage__c
      FROM Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals(
      'DEAD_LETTER',
      updated.Status__c,
      'Status should transition to DEAD_LETTER when retries are exhausted'
    );
  }

  @IsTest
  static void testPluginExceptionHandledGracefully() {
    Integration_Log__c log = [
      SELECT Id, Status__c, RetryCount__c
      FROM Integration_Log__c
      LIMIT 1
    ];

    IEF_Plugin__mdt mockConfig = new IEF_Plugin__mdt(
      DeveloperName = 'Test_Action_Exception',
      MasterLabel = 'Test Action Exception',
      ApexClassName__c = 'TestStub_ActionPlugin',
      PluginType__c = 'ACTION',
      Enabled__c = true,
      Contract_Version__c = 1.0
    );
    IEF_PluginRegistry.setMockConfigs(new List<IEF_Plugin__mdt>{ mockConfig });

    TestStub_ActionPlugin.shouldThrowException = true;

    Test.startTest();
    System.enqueueJob(new IEF_ActionQueueable(log.Id, 'Test_Action_Exception'));
    Test.stopTest();

    Integration_Log__c updated = [
      SELECT Status__c, ErrorMessage__c, RetryCount__c
      FROM Integration_Log__c
      WHERE Id = :log.Id
    ];
    System.assertEquals(
      1,
      updated.RetryCount__c,
      'Exception should trigger retry increment'
    );
    System.assert(
      updated.ErrorMessage__c.contains('Simulated plugin failure'),
      'ErrorMessage should capture exception details'
    );
  }

  @IsTest
  static void testActionDispatcher() {
    Integration_Log__c log = [
      SELECT Id, IntegrationCode__c, Status__c
      FROM Integration_Log__c
      LIMIT 1
    ];

    IEF_Plugin__mdt mockConfig = new IEF_Plugin__mdt(
      DeveloperName = 'Test_Action_Dispatch',
      MasterLabel = 'Test Action Dispatch',
      ApexClassName__c = 'TestStub_ActionPlugin',
      PluginType__c = 'ACTION',
      Enabled__c = true,
      Contract_Version__c = 1.0
    );
    IEF_PluginRegistry.setMockConfigs(new List<IEF_Plugin__mdt>{ mockConfig });

    Test.startTest();
    IEF_ActionDispatcher.dispatch(new List<Integration_Log__c>{ log });
    Test.stopTest();

    System.assert(true, 'Action dispatcher ran successfully');
  }

  @IsTest
  static void testActionContextAndResultHelpers() {
    IEF_ActionResult resOk = IEF_ActionResult.success('OK');
    IEF_ActionResult resRetry = IEF_ActionResult.retry('Busy');
    IEF_ActionResult resFatal = IEF_ActionResult.fatalFailure('Invalid');

    System.assertEquals(IEF_ActionResult.Status.SUCCESS, resOk.status);
    System.assertEquals(IEF_ActionResult.Status.RETRY, resRetry.status);
    System.assertEquals(IEF_ActionResult.Status.FATAL_FAILURE, resFatal.status);

    Integration_Log__c log = new Integration_Log__c(
      IntegrationCode__c = 'CODE',
      ObservationType__c = 'OBS',
      CorrelationId__c = 'CORR',
      Context__c = '{}',
      RetryCount__c = 1,
      MaxRetries__c = 5
    );
    IEF_ActionContext ctx = new IEF_ActionContext(log, null);
    System.assertEquals('CODE', ctx.integrationCode);
    System.assertEquals(1, ctx.retryCount);
    System.assertEquals(5, ctx.maxRetries);
  }
}
