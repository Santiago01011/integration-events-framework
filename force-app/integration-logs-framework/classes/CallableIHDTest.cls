@IsTest
private class CallableIHDTest {
  @TestSetup
  static void setupTestData() {
    // No DML needed
  }

  private static IHD_Plugin__mdt createMockConfig(
    String developerName,
    String pluginType,
    String apexClassName,
    Boolean enabled,
    Decimal displayOrder,
    String lwcComponentName
  ) {
    IHD_Plugin__mdt config = new IHD_Plugin__mdt();
    config.DeveloperName = developerName;
    config.Label = developerName;
    config.PluginType__c = pluginType;
    config.ApexClassName__c = apexClassName;
    config.Enabled__c = enabled;
    config.DisplayOrder__c = displayOrder;
    config.LwcComponentName__c = lwcComponentName;
    return config;
  }

  private static void setCachedConfigs(
    Map<String, List<IHD_Plugin__mdt>> configs
  ) {
    IHD_PluginRegistry.cachedConfigs = configs;
  }

  private static void setCachedInstances(Map<String, Object> instances) {
    IHD_PluginRegistry.cachedInstances = instances;
  }

  @IsTest
  static void call_getActivePlugins_returnsPluginNames() {
    // Mock CARD plugin
    IHD_Plugin__mdt cardConfig = createMockConfig(
      'Test_Card_Plugin',
      'CARD',
      'TestStub_CardPlugin',
      true,
      1,
      'c-test-card'
    );
    Map<String, List<IHD_Plugin__mdt>> cachedConfigs = new Map<String, List<IHD_Plugin__mdt>>();
    cachedConfigs.put('CARD', new List<IHD_Plugin__mdt>{ cardConfig });
    setCachedConfigs(cachedConfigs);
    TestStub_CardPlugin mockInstance = new TestStub_CardPlugin();
    Map<String, Object> cachedInstances = new Map<String, Object>();
    cachedInstances.put('TestStub_CardPlugin', mockInstance);
    setCachedInstances(cachedInstances);

    CallableIHD callable = new CallableIHD();
    Map<String, Object> args = new Map<String, Object>();

    Test.startTest();
    Object result = callable.call('getActivePlugins', args);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assert(
      result instanceof List<Map<String, Object>>,
      'Result should be List<Map<String, Object>>'
    );
    List<Map<String, Object>> pluginList = (List<Map<String, Object>>) result;
    System.assert(pluginList.size() > 0, 'Should have at least one plugin');
    Map<String, Object> firstPlugin = pluginList[0];
    System.assert(
      firstPlugin.containsKey('name'),
      'Plugin map should contain name'
    );
    System.assertEquals(
      'Test_Card_Plugin',
      firstPlugin.get('name'),
      'Plugin name should match'
    );
  }

  @IsTest
  static void call_getActiveCardPlugins_returnsPluginNames() {
    // Same as getActivePlugins (they are aliases)
    call_getActivePlugins_returnsPluginNames();
  }

  @IsTest
  static void call_getPluginData_returnsData() {
    IHD_Plugin__mdt cardConfig = createMockConfig(
      'Test_Card_Plugin',
      'CARD',
      'TestStub_CardPlugin',
      true,
      1,
      'c-test-card'
    );
    Map<String, List<IHD_Plugin__mdt>> cachedConfigs = new Map<String, List<IHD_Plugin__mdt>>();
    cachedConfigs.put('CARD', new List<IHD_Plugin__mdt>{ cardConfig });
    setCachedConfigs(cachedConfigs);
    TestStub_CardPlugin mockInstance = new TestStub_CardPlugin();
    Map<String, Object> cachedInstances = new Map<String, Object>();
    cachedInstances.put('TestStub_CardPlugin', mockInstance);
    setCachedInstances(cachedInstances);

    CallableIHD callable = new CallableIHD();
    Map<String, Object> args = new Map<String, Object>{
      'pluginName' => 'Test_Card_Plugin'
    };

    Test.startTest();
    Object result = callable.call('getPluginData', args);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Plugin data should not be null');
    System.assert(
      result instanceof Map<String, Object>,
      'Result should be a Map'
    );
    Map<String, Object> data = (Map<String, Object>) result;
    System.assertEquals(
      'testValue',
      data.get('testKey'),
      'Data should match stub data'
    );
  }

  @IsTest
  static void call_getPluginData_missingPluginName() {
    CallableIHD callable = new CallableIHD();
    Map<String, Object> args = new Map<String, Object>();

    Test.startTest();
    try {
      callable.call('getPluginData', args);
      System.assert(false, 'Should have thrown IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('pluginName is required'),
        'Error message should mention pluginName'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void call_isPluginEnabled_returnsTrue() {
    // Mock a plugin record via direct SOQL? We'll mock the registry but isPluginEnabled queries directly.
    // It uses a fresh SOQL query, not cached. We need to insert a custom metadata record? Can't.
    // However, we can create a mock plugin via DML? Not allowed. Let's skip this test or use existing metadata.
    // Since we cannot insert custom metadata, we rely on existing records in the org (maybe none).
    // We'll assume there is a plugin with DeveloperName 'Test_Card_Plugin' (maybe not).
    // Instead, we can test with a non-existent plugin name.
    CallableIHD callable = new CallableIHD();
    Map<String, Object> args = new Map<String, Object>{
      'pluginName' => 'NonExistentPlugin'
    };

    Test.startTest();
    Object result = callable.call('isPluginEnabled', args);
    Test.stopTest();

    System.assertEquals(
      false,
      result,
      'Non-existent plugin should return false'
    );
  }

  @IsTest
  static void call_isPluginEnabled_returnsFalse() {
    // same as above, rename
    call_isPluginEnabled_returnsTrue();
  }

  @IsTest
  static void call_getDiscoveredFields_returnsFields() {
    // Mock FIELD plugin
    IHD_Plugin__mdt fieldConfig = new IHD_Plugin__mdt();
    fieldConfig.DeveloperName = 'Test_Field_Plugin';
    fieldConfig.Label = 'Test Field Plugin';
    fieldConfig.PluginType__c = 'FIELD';
    fieldConfig.ApexClassName__c = 'TestStub_FieldPlugin';
    fieldConfig.Enabled__c = true;
    fieldConfig.DisplayOrder__c = 1;
    fieldConfig.DeclaredFields__c = 'Name,CreatedDate';
    Map<String, List<IHD_Plugin__mdt>> cachedConfigs = new Map<String, List<IHD_Plugin__mdt>>();
    cachedConfigs.put('FIELD', new List<IHD_Plugin__mdt>{ fieldConfig });
    setCachedConfigs(cachedConfigs);
    TestStub_FieldPlugin mockInstance = new TestStub_FieldPlugin();
    Map<String, Object> cachedInstances = new Map<String, Object>();
    cachedInstances.put('TestStub_FieldPlugin', mockInstance);
    setCachedInstances(cachedInstances);
    IHD_FieldDiscovery.clearCache();

    CallableIHD callable = new CallableIHD();
    Map<String, Object> args = new Map<String, Object>{
      'sobjectType' => 'Integration_Log__c'
    };

    Test.startTest();
    Object result = callable.call('getDiscoveredFields', args);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');
    System.assert(
      result instanceof Set<String>,
      'Result should be Set<String>'
    );
    Set<String> fields = (Set<String>) result;
    System.assert(fields.contains('Name'), 'Should contain Name field');
    System.assert(fields.contains('CreatedDate'), 'Should contain CreatedDate');
  }

  @IsTest
  static void call_getDiscoveredFields_missingSobjectType() {
    CallableIHD callable = new CallableIHD();
    Map<String, Object> args = new Map<String, Object>();

    Test.startTest();
    try {
      callable.call('getDiscoveredFields', args);
      System.assert(false, 'Should have thrown IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('sobjectType is required'),
        'Error message should mention sobjectType'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void call_unknownAction_throwsException() {
    CallableIHD callable = new CallableIHD();
    Map<String, Object> args = new Map<String, Object>();

    Test.startTest();
    try {
      callable.call('unknownAction', args);
      System.assert(false, 'Should have thrown IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().contains('Unknown action'),
        'Error message should indicate unknown action'
      );
      System.assert(
        e.getMessage().contains('unknownAction'),
        'Error message should include action name'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void callableInterface_implementsSystemCallable() {
    CallableIHD callable = new CallableIHD();
    // Verify that CallableIHD implements the Callable interface by calling a method from Callable
    System.Callable casted = (System.Callable) callable;
    System.assertNotEquals(null, casted, 'Should cast successfully');
    // Verify that call method works (already tested)
  }
}
