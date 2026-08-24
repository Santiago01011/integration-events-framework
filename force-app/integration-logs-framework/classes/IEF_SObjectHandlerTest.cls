@IsTest
private class IEF_SObjectHandlerTest {
  @TestSetup
  static void setupTestData() {
    // No DML needed
  }

  private static IEF_Plugin__mdt createMockConfig(
    String developerName,
    String pluginType,
    String apexClassName,
    Boolean enabled,
    Decimal displayOrder,
    String sobjectType
  ) {
    IEF_Plugin__mdt config = new IEF_Plugin__mdt();
    config.DeveloperName = developerName;
    config.Label = developerName;
    config.PluginType__c = pluginType;
    config.ApexClassName__c = apexClassName;
    config.Enabled__c = enabled;
    config.DisplayOrder__c = displayOrder;
    config.SObjectType__c = sobjectType;
    return config;
  }

  private static void setCachedConfigs(
    Map<String, List<IEF_Plugin__mdt>> configs
  ) {
    IEF_PluginRegistry.cachedConfigs = configs;
  }

  private static void setCachedInstances(Map<String, Object> instances) {
    IEF_PluginRegistry.cachedInstances = instances;
  }

  @IsTest
  static void tryCatch_isolatesFailingPlugins() {
    // Reset static variables
    TestStub_TriggerPlugin.reset();
    IEF_TestTriggerPluginCapture.reset();
    IEF_PluginRegistry.clearCache();

    // Configure the throwing plugin to throw an exception
    TestStub_TriggerPlugin.shouldThrow = true;

    // Create mock trigger plugin configs
    IEF_Plugin__mdt throwConfig = createMockConfig(
      'Test_Trigger_Plugin_Throw',
      'TRIGGER',
      'TestStub_TriggerPlugin',
      true,
      1,
      'Integration_Log__c'
    );
    IEF_Plugin__mdt captureConfig = createMockConfig(
      'Test_Trigger_Plugin_Capture',
      'TRIGGER',
      'IEF_TestTriggerPluginCapture',
      true,
      2,
      'Integration_Log__c'
    );
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put(
      'TRIGGER',
      new List<IEF_Plugin__mdt>{ throwConfig, captureConfig }
    );
    setCachedConfigs(cachedConfigs);
    // Mock instances
    TestStub_TriggerPlugin throwInstance = new TestStub_TriggerPlugin();
    IEF_TestTriggerPluginCapture captureInstance = new IEF_TestTriggerPluginCapture();
    Map<String, Object> cachedInstances = new Map<String, Object>();
    cachedInstances.put('TestStub_TriggerPlugin', throwInstance);
    cachedInstances.put('IEF_TestTriggerPluginCapture', captureInstance);
    setCachedInstances(cachedInstances);

    // Insert a log to trigger the trigger
    Test.startTest();
    Integration_Log__c log = new Integration_Log__c(
      IntegrationCode__c = 'TEST',
      ObservationType__c = 'REQUEST_DISPATCHED',
      Context__c = '{}',
      CorrelationId__c = 'CORR-TEST'
    );
    insert log;
    Test.stopTest();

    // The trigger fires for both BEFORE_INSERT and AFTER_INSERT, so each plugin executes twice.
    // Verify that the capturing plugin still executed despite the exception
    System.assertEquals(
      2,
      IEF_TestTriggerPluginCapture.executionCount,
      'Capturing plugin should have executed twice (before and after insert)'
    );
    System.assertNotEquals(
      null,
      IEF_TestTriggerPluginCapture.lastContext,
      'Context should be captured'
    );
    // The last context could be either BEFORE_INSERT or AFTER_INSERT depending on execution order.
    Set<System.TriggerOperation> validOps = new Set<System.TriggerOperation>{
      System.TriggerOperation.BEFORE_INSERT,
      System.TriggerOperation.AFTER_INSERT
    };
    System.assert(
      validOps.contains(IEF_TestTriggerPluginCapture.lastContext.operationType),
      'Operation type should be BEFORE_INSERT or AFTER_INSERT'
    );
    // The throwing plugin's execution count should also be 2 (it threw after increment each time)
    System.assertEquals(
      2,
      TestStub_TriggerPlugin.executionCount,
      'Throwing plugin should have executed twice'
    );
  }

  @IsTest
  static void execute_isCalledForTriggerOperation() {
    IEF_TestTriggerPluginCapture.reset();
    IEF_PluginRegistry.clearCache();

    // Create mock trigger plugin config
    IEF_Plugin__mdt captureConfig = createMockConfig(
      'Test_Trigger_Plugin_Capture',
      'TRIGGER',
      'IEF_TestTriggerPluginCapture',
      true,
      1,
      'Integration_Log__c'
    );
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('TRIGGER', new List<IEF_Plugin__mdt>{ captureConfig });
    setCachedConfigs(cachedConfigs);
    IEF_TestTriggerPluginCapture captureInstance = new IEF_TestTriggerPluginCapture();
    Map<String, Object> cachedInstances = new Map<String, Object>();
    cachedInstances.put('IEF_TestTriggerPluginCapture', captureInstance);
    setCachedInstances(cachedInstances);

    // Insert a log to trigger BEFORE_INSERT and AFTER_INSERT
    Test.startTest();
    Integration_Log__c log = new Integration_Log__c(
      IntegrationCode__c = 'TEST2',
      ObservationType__c = 'REQUEST_DISPATCHED',
      Context__c = '{"test": true}',
      CorrelationId__c = 'CORR-TEST2'
    );
    insert log;
    Test.stopTest();

    // The trigger fires for both BEFORE_INSERT and AFTER_INSERT, so plugin executes twice.
    System.assertEquals(
      2,
      IEF_TestTriggerPluginCapture.executionCount,
      'Plugin should be executed twice (before and after insert)'
    );
    System.assertEquals(
      'Test_Trigger_Plugin_Capture',
      IEF_TestTriggerPluginCapture.lastConfig.DeveloperName,
      'Config should match the plugin'
    );
    System.assertNotEquals(
      null,
      IEF_TestTriggerPluginCapture.lastContext.newRecords,
      'newRecords should be populated'
    );
    System.assertEquals(
      1,
      IEF_TestTriggerPluginCapture.lastContext.newRecords.size(),
      'Should have one new record'
    );
    // Verify operation type is one of the two
    Set<System.TriggerOperation> validOps = new Set<System.TriggerOperation>{
      System.TriggerOperation.BEFORE_INSERT,
      System.TriggerOperation.AFTER_INSERT
    };
    System.assert(
      validOps.contains(IEF_TestTriggerPluginCapture.lastContext.operationType),
      'Operation type should be BEFORE_INSERT or AFTER_INSERT'
    );
  }

  @IsTest
  static void handlerCanBeCalledDirectly() {
    // Test that we can instantiate a concrete handler and call getSObjectType
    IntegrationLogTriggerHandler handler = new IntegrationLogTriggerHandler();
    System.assertEquals(
      'Integration_Log__c',
      handler.getSObjectType(),
      'Handler should return correct SObject type'
    );
  }
}
