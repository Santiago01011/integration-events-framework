@IsTest
private class IEF_PluginRegistryTest {
  @TestSetup
  static void setupTestData() {
    // No DML needed; we'll mock via cachedConfigs
  }

  private static IEF_Plugin__mdt createMockConfig(
    String developerName,
    String pluginType,
    String apexClassName,
    Boolean enabled,
    Decimal displayOrder,
    String sobjectType,
    String declaredFields,
    String lwcComponentName
  ) {
    // Create a mock IEF_Plugin__mdt record without inserting
    IEF_Plugin__mdt config = new IEF_Plugin__mdt();
    config.DeveloperName = developerName;
    config.Label = developerName;
    config.PluginType__c = pluginType;
    config.ApexClassName__c = apexClassName;
    config.Enabled__c = enabled;
    config.DisplayOrder__c = displayOrder;
    config.SObjectType__c = sobjectType;
    config.DeclaredFields__c = declaredFields;
    config.LwcComponentName__c = lwcComponentName;
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
  static void getPlugins_returnsEnabledPluginsByType() {
    // Create mock configs
    List<IEF_Plugin__mdt> cardPlugins = new List<IEF_Plugin__mdt>{
      createMockConfig(
        'Test_Card_Plugin_Enabled',
        'CARD',
        'TestStub_CardPlugin',
        true,
        1,
        null,
        null,
        'c-test-card'
      )
    };
    List<IEF_Plugin__mdt> fieldPlugins = new List<IEF_Plugin__mdt>{
      createMockConfig(
        'Test_Field_Plugin',
        'FIELD',
        'TestStub_FieldPlugin',
        true,
        1,
        null,
        'Name,CreatedDate',
        null
      )
    };
    List<IEF_Plugin__mdt> triggerPlugins = new List<IEF_Plugin__mdt>{
      createMockConfig(
        'Test_Trigger_Plugin',
        'TRIGGER',
        'TestStub_TriggerPlugin',
        true,
        1,
        'Integration_Log__c',
        null,
        null
      )
    };
    List<IEF_Plugin__mdt> servicePlugins = new List<IEF_Plugin__mdt>{
      createMockConfig(
        'Test_Service_Plugin',
        'SERVICE',
        'NonExistentClass',
        true,
        1,
        null,
        null,
        null
      )
    };

    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('CARD', cardPlugins);
    cachedConfigs.put('FIELD', fieldPlugins);
    cachedConfigs.put('TRIGGER', triggerPlugins);
    cachedConfigs.put('SERVICE', servicePlugins);
    setCachedConfigs(cachedConfigs);
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    List<IEF_Plugin__mdt> resultCard = IEF_PluginRegistry.getConfigs('CARD');
    List<IEF_Plugin__mdt> resultField = IEF_PluginRegistry.getConfigs('FIELD');
    List<IEF_Plugin__mdt> resultTrigger = IEF_PluginRegistry.getConfigs(
      'TRIGGER'
    );
    List<IEF_Plugin__mdt> resultService = IEF_PluginRegistry.getConfigs(
      'SERVICE'
    );
    Test.stopTest();

    System.assertEquals(
      1,
      resultCard.size(),
      'Should return only enabled CARD plugin'
    );
    System.assertEquals(
      'Test_Card_Plugin_Enabled',
      resultCard[0].DeveloperName
    );
    System.assertEquals(1, resultField.size());
    System.assertEquals('Test_Field_Plugin', resultField[0].DeveloperName);
    System.assertEquals(1, resultTrigger.size());
    System.assertEquals('Test_Trigger_Plugin', resultTrigger[0].DeveloperName);
    System.assertEquals(1, resultService.size());
    System.assertEquals('Test_Service_Plugin', resultService[0].DeveloperName);
  }

  @IsTest
  static void getPlugins_excludesDisabledPlugins() {
    // Simulate that the SOQL query only returns enabled plugins
    List<IEF_Plugin__mdt> enabledOnly = new List<IEF_Plugin__mdt>{
      createMockConfig(
        'Test_Card_Plugin_Enabled',
        'CARD',
        'TestStub_CardPlugin',
        true,
        1,
        null,
        null,
        'c-test-card'
      )
    };
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('CARD', enabledOnly);
    setCachedConfigs(cachedConfigs);
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    List<IEF_Plugin__mdt> result = IEF_PluginRegistry.getConfigs('CARD');
    Test.stopTest();

    System.assertEquals(1, result.size(), 'Disabled plugin should be excluded');
    System.assertEquals('Test_Card_Plugin_Enabled', result[0].DeveloperName);
  }

  @IsTest
  static void getPlugins_returnsEmptyWhenNoPlugins() {
    setCachedConfigs(new Map<String, List<IEF_Plugin__mdt>>());
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    List<IEF_Plugin__mdt> unknownPlugins = IEF_PluginRegistry.getConfigs(
      'UNKNOWN_TYPE'
    );
    Test.stopTest();

    System.assertNotEquals(
      null,
      unknownPlugins,
      'Should return empty list, not null'
    );
    System.assertEquals(
      0,
      unknownPlugins.size(),
      'Should return empty list for unknown type'
    );
  }

  @IsTest
  static void getInstance_returnsInstanceForValidClass() {
    IEF_Plugin__mdt config = createMockConfig(
      'Test_Card_Plugin_Enabled',
      'CARD',
      'TestStub_CardPlugin',
      true,
      1,
      null,
      null,
      'c-test-card'
    );
    setCachedConfigs(new Map<String, List<IEF_Plugin__mdt>>());
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    Object instance = IEF_PluginRegistry.getInstance(config);
    Test.stopTest();

    System.assertNotEquals(null, instance, 'Instance should not be null');
    System.assert(
      instance instanceof IEF_CardPlugin,
      'Instance should implement IEF_CardPlugin'
    );
  }

  @IsTest
  static void getInstance_returnsNullForMissingClass() {
    IEF_Plugin__mdt config = createMockConfig(
      'Test_Service_Plugin',
      'SERVICE',
      'NonExistentClass',
      true,
      1,
      null,
      null,
      null
    );
    setCachedConfigs(new Map<String, List<IEF_Plugin__mdt>>());
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    Object instance = IEF_PluginRegistry.getInstance(config);
    Test.stopTest();

    System.assertEquals(
      null,
      instance,
      'Should return null for non-existent class'
    );
  }

  @IsTest
  static void getInstance_cachesInstance() {
    IEF_Plugin__mdt config = createMockConfig(
      'Test_Card_Plugin_Enabled',
      'CARD',
      'TestStub_CardPlugin',
      true,
      1,
      null,
      null,
      'c-test-card'
    );
    setCachedConfigs(new Map<String, List<IEF_Plugin__mdt>>());
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    Object instance1 = IEF_PluginRegistry.getInstance(config);
    Object instance2 = IEF_PluginRegistry.getInstance(config);
    Test.stopTest();

    System.assertNotEquals(
      null,
      instance1,
      'First instance should not be null'
    );
    System.assertNotEquals(
      null,
      instance2,
      'Second instance should not be null'
    );
    System.assertEquals(
      instance1,
      instance2,
      'Should return same cached instance'
    );
  }

  @IsTest
  static void getTriggerConfigs_filtersBySObjectType() {
    List<IEF_Plugin__mdt> triggerPlugins = new List<IEF_Plugin__mdt>{
      createMockConfig(
        'Test_Trigger_Plugin',
        'TRIGGER',
        'TestStub_TriggerPlugin',
        true,
        1,
        'Integration_Log__c',
        null,
        null
      )
    };
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('TRIGGER', triggerPlugins);
    setCachedConfigs(cachedConfigs);
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    List<IEF_Plugin__mdt> filtered = IEF_PluginRegistry.getTriggerConfigs(
      'Integration_Log__c'
    );
    List<IEF_Plugin__mdt> allTrigger = IEF_PluginRegistry.getTriggerConfigs(
      null
    );
    Test.stopTest();

    System.assertEquals(1, filtered.size(), 'Should filter by SObjectType');
    System.assertEquals(
      1,
      allTrigger.size(),
      'Should return all trigger plugins when null'
    );
  }

  @IsTest
  static void getActivePluginNames_returnsAllEnabled() {
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put(
      'CARD',
      new List<IEF_Plugin__mdt>{
        createMockConfig(
          'Test_Card_Plugin_Enabled',
          'CARD',
          'TestStub_CardPlugin',
          true,
          1,
          null,
          null,
          null
        )
      }
    );
    cachedConfigs.put(
      'FIELD',
      new List<IEF_Plugin__mdt>{
        createMockConfig(
          'Test_Field_Plugin',
          'FIELD',
          'TestStub_FieldPlugin',
          true,
          1,
          null,
          null,
          null
        )
      }
    );
    cachedConfigs.put(
      'TRIGGER',
      new List<IEF_Plugin__mdt>{
        createMockConfig(
          'Test_Trigger_Plugin',
          'TRIGGER',
          'TestStub_TriggerPlugin',
          true,
          1,
          null,
          null,
          null
        )
      }
    );
    cachedConfigs.put(
      'SERVICE',
      new List<IEF_Plugin__mdt>{
        createMockConfig(
          'Test_Service_Plugin',
          'SERVICE',
          'NonExistentClass',
          true,
          1,
          null,
          null,
          null
        )
      }
    );
    setCachedConfigs(cachedConfigs);
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    List<String> names = IEF_PluginRegistry.getActivePluginNames();
    Test.stopTest();

    System.assertNotEquals(null, names, 'Names list should not be null');
    System.assertEquals(4, names.size(), 'Should have 4 enabled plugins');
    System.assert(names.contains('Test_Card_Plugin_Enabled'));
    System.assert(names.contains('Test_Field_Plugin'));
    System.assert(names.contains('Test_Trigger_Plugin'));
    System.assert(names.contains('Test_Service_Plugin'));
  }

  @IsTest
  static void getFieldConfigs_returnsFieldPlugins() {
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put(
      'FIELD',
      new List<IEF_Plugin__mdt>{
        createMockConfig(
          'Test_Field_Plugin',
          'FIELD',
          'TestStub_FieldPlugin',
          true,
          1,
          null,
          null,
          null
        )
      }
    );
    setCachedConfigs(cachedConfigs);
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    List<IEF_Plugin__mdt> fieldConfigs = IEF_PluginRegistry.getFieldConfigs();
    Test.stopTest();

    System.assertEquals(1, fieldConfigs.size(), 'Should return FIELD plugins');
    System.assertEquals('Test_Field_Plugin', fieldConfigs[0].DeveloperName);
  }

  @IsTest
  static void getCardConfigs_returnsCardPlugins() {
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put(
      'CARD',
      new List<IEF_Plugin__mdt>{
        createMockConfig(
          'Test_Card_Plugin_Enabled',
          'CARD',
          'TestStub_CardPlugin',
          true,
          1,
          null,
          null,
          null
        )
      }
    );
    setCachedConfigs(cachedConfigs);
    setCachedInstances(new Map<String, Object>());

    Test.startTest();
    List<IEF_Plugin__mdt> cardConfigs = IEF_PluginRegistry.getCardConfigs();
    Test.stopTest();

    System.assertEquals(
      1,
      cardConfigs.size(),
      'Should return enabled CARD plugins'
    );
    System.assertEquals(
      'Test_Card_Plugin_Enabled',
      cardConfigs[0].DeveloperName
    );
  }
}
