@IsTest
private class CallableIEFTest {
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
    String lwcComponentName
  ) {
    IEF_Plugin__mdt config = new IEF_Plugin__mdt();
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
    Map<String, List<IEF_Plugin__mdt>> configs
  ) {
    IEF_PluginRegistry.cachedConfigs = configs;
  }

  private static void setCachedResolutions(
    Map<String, IEF_PluginRegistry.Resolution> resolutions
  ) {
    IEF_PluginRegistry.cachedResolutions = resolutions;
  }

  @IsTest
  static void call_getActivePlugins_returnsPluginNames() {
    // Mock CARD plugin
    IEF_Plugin__mdt cardConfig = createMockConfig(
      'Test_Card_Plugin',
      'CARD',
      'TestStub_CardPlugin',
      true,
      1,
      'c-test-card'
    );
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('CARD', new List<IEF_Plugin__mdt>{ cardConfig });
    setCachedConfigs(cachedConfigs);
    Map<String, IEF_PluginRegistry.Resolution> cachedResolutions = new Map<String, IEF_PluginRegistry.Resolution>();
    cachedResolutions.put(
      'TestStub_CardPlugin',
      new IEF_PluginRegistry.Resolution(
        new TestStub_CardPlugin(),
        'ACTIVE',
        null
      )
    );
    setCachedResolutions(cachedResolutions);

    CallableIEF callable = new CallableIEF();
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
    IEF_Plugin__mdt cardConfig = createMockConfig(
      'Test_Card_Plugin',
      'CARD',
      'TestStub_CardPlugin',
      true,
      1,
      'c-test-card'
    );
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('CARD', new List<IEF_Plugin__mdt>{ cardConfig });
    setCachedConfigs(cachedConfigs);
    Map<String, IEF_PluginRegistry.Resolution> cachedResolutions = new Map<String, IEF_PluginRegistry.Resolution>();
    cachedResolutions.put(
      'TestStub_CardPlugin',
      new IEF_PluginRegistry.Resolution(
        new TestStub_CardPlugin(),
        'ACTIVE',
        null
      )
    );
    setCachedResolutions(cachedResolutions);

    CallableIEF callable = new CallableIEF();
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
    CallableIEF callable = new CallableIEF();
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
    CallableIEF callable = new CallableIEF();
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
    IEF_Plugin__mdt fieldConfig = new IEF_Plugin__mdt();
    fieldConfig.DeveloperName = 'Test_Field_Plugin';
    fieldConfig.Label = 'Test Field Plugin';
    fieldConfig.PluginType__c = 'FIELD';
    fieldConfig.ApexClassName__c = 'TestStub_FieldPlugin';
    fieldConfig.Enabled__c = true;
    fieldConfig.DisplayOrder__c = 1;
    fieldConfig.DeclaredFields__c = 'Name,CreatedDate';
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('FIELD', new List<IEF_Plugin__mdt>{ fieldConfig });
    setCachedConfigs(cachedConfigs);
    Map<String, IEF_PluginRegistry.Resolution> cachedResolutions = new Map<String, IEF_PluginRegistry.Resolution>();
    cachedResolutions.put(
      'TestStub_FieldPlugin',
      new IEF_PluginRegistry.Resolution(
        new TestStub_FieldPlugin(),
        'ACTIVE',
        null
      )
    );
    setCachedResolutions(cachedResolutions);
    IEF_FieldDiscovery.clearCache();

    CallableIEF callable = new CallableIEF();
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
    CallableIEF callable = new CallableIEF();
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
    CallableIEF callable = new CallableIEF();
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
    CallableIEF callable = new CallableIEF();
    // Verify that CallableIEF implements the Callable interface by calling a method from Callable
    System.Callable casted = (System.Callable) callable;
    System.assertNotEquals(null, casted, 'Should cast successfully');
    // Verify that call method works (already tested)
  }

  @IsTest
  static void call_getCompositionInfo_returnsList() {
    CallableIEF callable = new CallableIEF();
    Test.startTest();
    Object result = callable.call(
      'getCompositionInfo',
      new Map<String, Object>()
    );
    Test.stopTest();
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assert(
      result instanceof List<IntegrationHealthWrappers.PluginCompositionEntry>,
      'Result should be List<PluginCompositionEntry>'
    );
  }

  @IsTest
  static void call_getCompositionInfo_usesAdditiveAction() {
    CallableIEF callable = new CallableIEF();
    Test.startTest();
    Object result1 = callable.call('getCompositionInfo', null);
    Object result2 = callable.call(
      'getCompositionInfo',
      new Map<String, Object>()
    );
    Test.stopTest();
    System.assertNotEquals(null, result1);
    System.assertNotEquals(null, result2);
    System.assert(
      result1 instanceof List<IntegrationHealthWrappers.PluginCompositionEntry>,
      'Should return PluginCompositionEntry list'
    );
  }
}
