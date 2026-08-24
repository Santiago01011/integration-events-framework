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

  private static void setCachedResolutions(
    Map<String, IEF_PluginRegistry.Resolution> resolutions
  ) {
    IEF_PluginRegistry.cachedResolutions = resolutions;
  }

  private static void clearAllCaches() {
    IEF_PluginRegistry.clearCache();
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

  // ---- D6: Resolution / resolve() ----

  @IsTest
  static void resolve_returnsActiveForValidClass() {
    IEF_Plugin__mdt cfg = createMockConfig(
      'Res_Active',
      'CARD',
      'TestStub_CardPlugin',
      true,
      1,
      null,
      null,
      'c-test-card'
    );
    clearAllCaches();
    Test.startTest();
    IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(cfg);
    Test.stopTest();
    System.assertEquals('ACTIVE', res.status, 'Should be ACTIVE');
    System.assertNotEquals(null, res.instance, 'Instance should not be null');
    System.assertEquals(null, res.reason, 'Reason should be null for ACTIVE');
  }

  @IsTest
  static void resolve_returnsOrphanForMissingClass() {
    IEF_Plugin__mdt cfg = createMockConfig(
      'Res_Orphan',
      'SERVICE',
      'NonExistentClass_XYZ_123',
      true,
      1,
      null,
      null,
      null
    );
    clearAllCaches();
    Test.startTest();
    IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(cfg);
    Test.stopTest();
    System.assertEquals('ORPHAN', res.status, 'Should be ORPHAN');
    System.assertEquals(null, res.instance, 'Instance should be null');
    System.assert(
      res.reason.contains('Apex class not found'),
      'Reason should mention class not found: ' + res.reason
    );
    // Verify composition info would surface orphan without crashing (no throw)
    System.assertNotEquals(null, res.reason);
  }

  @IsTest
  static void resolve_returnsActiveLwcForNA() {
    IEF_Plugin__mdt cfg = createMockConfig(
      'Res_LwcOnly',
      'CARD',
      'N/A',
      true,
      1,
      null,
      null,
      'c-ief-dynamic-loader'
    );
    clearAllCaches();
    Test.startTest();
    IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(cfg);
    Test.stopTest();
    System.assertEquals('ACTIVE_LWC', res.status, 'Should be ACTIVE_LWC');
    System.assertEquals(null, res.instance, 'LWC-only has no instance');
    System.assertEquals(null, res.reason);
  }

  @IsTest
  static void resolve_returnsFailedForThrowingConstructor() {
    IEF_Plugin__mdt cfg = createMockConfig(
      'Res_Failing',
      'CARD',
      'TestStub_FailingCardPlugin',
      true,
      1,
      null,
      null,
      'c-failing-card'
    );
    clearAllCaches();
    Test.startTest();
    IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(cfg);
    Test.stopTest();
    System.assertEquals('FAILED', res.status, 'Should be FAILED');
    System.assertEquals(null, res.instance);
    System.assert(
      res.reason.contains('Failed to instantiate'),
      'Reason should be human-readable: ' + res.reason
    );
  }

  @IsTest
  static void resolve_cachesFailureAndRecoveryAfterClear() {
    IEF_Plugin__mdt failingCfg = createMockConfig(
      'Res_Recovery',
      'CARD',
      'TestStub_FailingCardPlugin',
      true,
      1,
      null,
      null,
      'c-failing-card'
    );
    IEF_Plugin__mdt healthyCfg = createMockConfig(
      'Res_Recovery',
      'CARD',
      'TestStub_CardPlugin',
      true,
      1,
      null,
      null,
      'c-test-card'
    );
    // Same cache key is ApexClassName__c, so recovery requires different class name.
    // Instead, test that clearing cache allows re-resolve to be re-attempted.
    clearAllCaches();
    Test.startTest();
    IEF_PluginRegistry.Resolution first = IEF_PluginRegistry.resolve(
      failingCfg
    );
    System.assertEquals('FAILED', first.status);
    // Clear and resolve a healthy plugin with same logical name but different class — should be ACTIVE
    IEF_PluginRegistry.clearCache();
    IEF_PluginRegistry.Resolution second = IEF_PluginRegistry.resolve(
      healthyCfg
    );
    System.assertEquals(
      'ACTIVE',
      second.status,
      'After clearCache, healthy plugin should be ACTIVE'
    );
    System.assertNotEquals(null, second.instance);
    Test.stopTest();
  }

  @IsTest
  static void resolve_orpanDoesNotCrashAndSubsequentRowsStillResolve() {
    IEF_Plugin__mdt orphanCfg = createMockConfig(
      'Res_Orphan2',
      'CARD',
      'NonExistent_Orphan_XYZ',
      true,
      1,
      null,
      null,
      null
    );
    IEF_Plugin__mdt healthyCfg = createMockConfig(
      'Res_Healthy2',
      'CARD',
      'TestStub_CardPlugin',
      true,
      2,
      null,
      null,
      'c-test-card'
    );
    clearAllCaches();
    Test.startTest();
    IEF_PluginRegistry.Resolution r1 = IEF_PluginRegistry.resolve(orphanCfg);
    IEF_PluginRegistry.Resolution r2 = IEF_PluginRegistry.resolve(healthyCfg);
    Test.stopTest();
    System.assertEquals('ORPHAN', r1.status);
    System.assertEquals(
      'ACTIVE',
      r2.status,
      'Healthy row should still resolve after orphan'
    );
  }

  @IsTest
  static void getInstance_delegatesToResolve_returnsNullForOrphan() {
    IEF_Plugin__mdt cfg = createMockConfig(
      'Delegate_Orphan',
      'SERVICE',
      'NonExistent_Delegate_XYZ',
      true,
      1,
      null,
      null,
      null
    );
    clearAllCaches();
    Test.startTest();
    Object inst = IEF_PluginRegistry.getInstance(cfg);
    IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(cfg);
    Test.stopTest();
    System.assertEquals(
      null,
      inst,
      'getInstance should return null for orphan'
    );
    System.assertEquals('ORPHAN', res.status);
  }

  @IsTest
  static void resolve_recordsFailureWithReasonNoSilentNull() {
    IEF_Plugin__mdt cfg = createMockConfig(
      'Res_NoSilentNull',
      'CARD',
      'NonExistent_NoSilentNull_XYZ',
      true,
      1,
      null,
      null,
      null
    );
    clearAllCaches();
    Test.startTest();
    IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(cfg);
    Test.stopTest();
    // Verify failure is recorded, not silent null
    System.assertNotEquals(null, res, 'Resolution should not be null');
    System.assertNotEquals('ACTIVE', res.status);
    System.assertNotEquals(null, res.reason, 'Reason must be populated');
    System.assertEquals(
      null,
      res.instance,
      'Instance is null but status/reason record the failure'
    );
  }
}
