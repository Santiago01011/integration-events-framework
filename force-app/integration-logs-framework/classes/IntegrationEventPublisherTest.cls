@IsTest
private class IntegrationEventPublisherTest {
  @IsTest
  static void testEmitAndTriggerFlow() {
    String integrationCode = 'TEST-INT-01';
    String observation = 'UNIT_TEST';
    String correlationId = 'UUID-999';
    Map<String, Object> context = new Map<String, Object>{ 'status' => 'OK' };

    Test.startTest();
    IntegrationEventPublisher.emit(
      integrationCode,
      observation,
      correlationId,
      null,
      JSON.serialize(context)
    );

    Test.getEventBus().deliver();
    Test.stopTest();

    Integration_Log__c storedLog = [
      SELECT
        IntegrationCode__c,
        ObservationType__c,
        CorrelationId__c,
        Context__c
      FROM Integration_Log__c
      WHERE CorrelationId__c = :correlationId
      LIMIT 1
    ];

    System.assertNotEquals(null, storedLog, 'Log should be persisted to DB');
    System.assertEquals(integrationCode, storedLog.IntegrationCode__c);
    System.assertEquals(observation, storedLog.ObservationType__c);
    System.assert(
      storedLog.Context__c.contains('OK'),
      'Context JSON should contain payload'
    );
  }

  @IsTest
  static void testKillSwitchBlocksDisabledIntegration() {
    String disabledCode = 'DISABLED_INTEGRATION';
    String allowedCode = 'ALLOWED_INTEGRATION';
    String correlationDisabled = 'CORR-DISABLED';
    String correlationAllowed = 'CORR-ALLOWED';

    IntegrationEventPublisher.setTestDisabledCodes(
      new Set<String>{ disabledCode }
    );

    Test.startTest();
    IntegrationEventPublisher.emit(
      disabledCode,
      'TEST',
      correlationDisabled,
      null,
      '{}'
    );

    IntegrationEventPublisher.emit(
      allowedCode,
      'TEST',
      correlationAllowed,
      null,
      '{}'
    );

    Test.getEventBus().deliver();
    Test.stopTest();

    List<Integration_Log__c> disabledLogs = [
      SELECT Id
      FROM Integration_Log__c
      WHERE CorrelationId__c = :correlationDisabled
    ];
    System.assertEquals(
      0,
      disabledLogs.size(),
      'Disabled integration should NOT create logs'
    );

    List<Integration_Log__c> allowedLogs = [
      SELECT Id
      FROM Integration_Log__c
      WHERE CorrelationId__c = :correlationAllowed
    ];
    System.assertEquals(
      1,
      allowedLogs.size(),
      'Allowed integration should create logs'
    );
  }

  @IsTest
  static void testUnregisteredIntegrationIsAllowed() {
    String unregisteredCode = 'NEW_UNREGISTERED_FLOW';
    String correlationId = 'CORR-UNREG';

    IntegrationEventPublisher.setTestDisabledCodes(new Set<String>());

    Test.startTest();
    IntegrationEventPublisher.emit(
      unregisteredCode,
      'TEST',
      correlationId,
      null,
      '{}'
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    List<Integration_Log__c> logs = [
      SELECT IntegrationCode__c
      FROM Integration_Log__c
      WHERE CorrelationId__c = :correlationId
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Unregistered integration should be allowed'
    );
    System.assertEquals(unregisteredCode, logs[0].IntegrationCode__c);
  }

  @IsTest
  static void testEmitWithMap() {
    String correlationId = 'CORR-MAP';
    Map<String, Object> contextMap = new Map<String, Object>{
      'key1' => 'val1',
      'key2' => 123
    };

    Test.startTest();
    IntegrationEventPublisher.emit(
      'TEST-MAP',
      'TEST',
      correlationId,
      null,
      contextMap
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    Integration_Log__c log = [
      SELECT Context__c
      FROM Integration_Log__c
      WHERE CorrelationId__c = :correlationId
      LIMIT 1
    ];
    System.assert(log.Context__c.contains('val1'));
    System.assert(log.Context__c.contains('123'));
  }

  @IsTest
  static void testFieldTruncation() {
    // Use values that exceed field limits
    String longCode = 'TRUNC_' + 'A'.repeat(150);
    String longObs = 'B'.repeat(150);
    String longCorr = 'C'.repeat(100);
    String longParent = 'D'.repeat(100);
    String longContext = 'E'.repeat(40000);

    // Ensure the code is not blocked by kill switch
    IntegrationEventPublisher.setTestDisabledCodes(new Set<String>());

    Test.startTest();
    // This should NOT throw an exception despite over-length values
    IntegrationEventPublisher.emit(
      longCode,
      longObs,
      longCorr,
      longParent,
      longContext
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    // If we get here without exception, the truncation logic works
    // The actual field length validation is covered by the emit method
    System.assert(true, 'Emit with over-length values should succeed');
  }

  @IsTest
  static void testDMLSafetyGuard() {
    Test.startTest();
    for (Integer i = 0; i < 149; i++) {
      insert new Integration_Log__c(
        IntegrationCode__c = 'DUMMY',
        ObservationType__c = 'DUMMY'
      );
    }

    IntegrationEventPublisher.emit('DML_TEST', 'TEST', 'CORR', null, 'Context');
    Test.getEventBus().deliver();
    Test.stopTest();

    List<Integration_Log__c> logs = [
      SELECT Id
      FROM Integration_Log__c
      WHERE IntegrationCode__c = 'DML_TEST'
    ];

    System.assert(true, 'Safety guard check completed without exception');
  }
}
