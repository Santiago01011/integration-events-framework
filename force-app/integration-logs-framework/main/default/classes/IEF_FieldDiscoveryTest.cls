@IsTest
private class IEF_FieldDiscoveryTest {
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
    String declaredFields
  ) {
    IEF_Plugin__mdt config = new IEF_Plugin__mdt();
    config.DeveloperName = developerName;
    config.Label = developerName;
    config.PluginType__c = pluginType;
    config.ApexClassName__c = apexClassName;
    config.Enabled__c = enabled;
    config.DisplayOrder__c = displayOrder;
    config.DeclaredFields__c = declaredFields;
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
  static void getDynamicFields_includesDeclaredFields() {
    // Plugin that does NOT implement IEF_FieldPlugin, uses DeclaredFields__c
    IEF_Plugin__mdt config = createMockConfig(
      'Field_Plugin_Existing',
      'FIELD',
      'TestStub_CardPlugin', // not a field plugin
      true,
      1,
      'Name,CreatedDate'
    );
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('FIELD', new List<IEF_Plugin__mdt>{ config });
    setCachedConfigs(cachedConfigs);
    // Mock instance for the plugin
    TestStub_CardPlugin mockInstance = new TestStub_CardPlugin();
    Map<String, Object> cachedInstances = new Map<String, Object>();
    cachedInstances.put('TestStub_CardPlugin', mockInstance);
    setCachedInstances(cachedInstances);
    IEF_FieldDiscovery.clearCache();

    Test.startTest();
    Set<String> fields = IEF_FieldDiscovery.getDiscoveredFields(
      'Integration_Log__c'
    );
    Test.stopTest();

    System.assertNotEquals(null, fields, 'Fields set should not be null');
    System.assert(fields.contains('Name'), 'Should include Name field');
    System.assert(
      fields.contains('CreatedDate'),
      'Should include CreatedDate field'
    );
    System.assert(
      !fields.contains('NonExistentField__c'),
      'Should not include non-existent field'
    );
  }

  @IsTest
  static void getDynamicFields_excludesNonExistentFields() {
    IEF_Plugin__mdt config = createMockConfig(
      'Field_Plugin_NonExistent',
      'FIELD',
      'TestStub_CardPlugin',
      true,
      1,
      'NonExistentField__c,CreatedDate'
    );
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('FIELD', new List<IEF_Plugin__mdt>{ config });
    setCachedConfigs(cachedConfigs);
    TestStub_CardPlugin mockInstance = new TestStub_CardPlugin();
    Map<String, Object> cachedInstances = new Map<String, Object>();
    cachedInstances.put('TestStub_CardPlugin', mockInstance);
    setCachedInstances(cachedInstances);
    IEF_FieldDiscovery.clearCache();

    Test.startTest();
    Set<String> fields = IEF_FieldDiscovery.getDiscoveredFields(
      'Integration_Log__c'
    );
    Test.stopTest();

    System.assert(
      !fields.contains('NonExistentField__c'),
      'Non-existent custom field should be excluded'
    );
    System.assert(
      fields.contains('CreatedDate'),
      'Existing field should be included'
    );
  }

  @IsTest
  static void getDynamicFields_returnsEmptyForNoFieldPlugins() {
    // No FIELD plugins
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('FIELD', new List<IEF_Plugin__mdt>());
    setCachedConfigs(cachedConfigs);
    setCachedInstances(new Map<String, Object>());
    IEF_FieldDiscovery.clearCache();

    Test.startTest();
    Set<String> fields = IEF_FieldDiscovery.getDiscoveredFields(
      'Integration_Log__c'
    );
    Test.stopTest();

    System.assertNotEquals(null, fields, 'Should return empty set, not null');
    System.assertEquals(0, fields.size(), 'Should return empty set');
  }

  @IsTest
  static void getDynamicFields_handlesBlankDeclaredFields() {
    IEF_Plugin__mdt config = createMockConfig(
      'Field_Plugin_Blank',
      'FIELD',
      'TestStub_CardPlugin',
      true,
      1,
      ''
    );
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('FIELD', new List<IEF_Plugin__mdt>{ config });
    setCachedConfigs(cachedConfigs);
    TestStub_CardPlugin mockInstance = new TestStub_CardPlugin();
    Map<String, Object> cachedInstances = new Map<String, Object>();
    cachedInstances.put('TestStub_CardPlugin', mockInstance);
    setCachedInstances(cachedInstances);
    IEF_FieldDiscovery.clearCache();

    Test.startTest();
    Set<String> fields = IEF_FieldDiscovery.getDiscoveredFields(
      'Integration_Log__c'
    );
    Test.stopTest();

    // Should still have fields from other plugins (none in this case)
    System.assertEquals(0, fields.size(), 'Should have no fields');
  }

  @IsTest
  static void getDiscoveredFieldsCsv_returnsCommaSeparated() {
    IEF_Plugin__mdt config = createMockConfig(
      'Field_Plugin_Existing',
      'FIELD',
      'TestStub_CardPlugin',
      true,
      1,
      'Name,CreatedDate'
    );
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('FIELD', new List<IEF_Plugin__mdt>{ config });
    setCachedConfigs(cachedConfigs);
    TestStub_CardPlugin mockInstance = new TestStub_CardPlugin();
    Map<String, Object> cachedInstances = new Map<String, Object>();
    cachedInstances.put('TestStub_CardPlugin', mockInstance);
    setCachedInstances(cachedInstances);
    IEF_FieldDiscovery.clearCache();

    Test.startTest();
    String csv = IEF_FieldDiscovery.getDiscoveredFieldsCsv(
      'Integration_Log__c'
    );
    Test.stopTest();

    System.assertNotEquals(null, csv, 'CSV should not be null');
    System.assert(csv.contains('Name'), 'CSV should contain Name');
    System.assert(
      csv.contains('CreatedDate'),
      'CSV should contain CreatedDate'
    );
    // Should not contain duplicates
    System.assert(
      !csv.contains('Name,Name'),
      'CSV should not have duplicate fields'
    );
  }

  @IsTest
  static void getDiscoveredFieldsCsv_emptyWhenNoFields() {
    Map<String, List<IEF_Plugin__mdt>> cachedConfigs = new Map<String, List<IEF_Plugin__mdt>>();
    cachedConfigs.put('FIELD', new List<IEF_Plugin__mdt>());
    setCachedConfigs(cachedConfigs);
    setCachedInstances(new Map<String, Object>());
    IEF_FieldDiscovery.clearCache();

    Test.startTest();
    String csv = IEF_FieldDiscovery.getDiscoveredFieldsCsv(
      'Integration_Log__c'
    );
    Test.stopTest();

    System.assertEquals('', csv, 'CSV should be empty string');
  }
}
