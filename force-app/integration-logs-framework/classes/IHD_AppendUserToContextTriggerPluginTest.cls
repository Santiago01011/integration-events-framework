@IsTest
private class IHD_AppendUserToContextTriggerPluginTest {
  @TestSetup
  static void setupTestData() {
    // No persistent sObject needed; plugin is executed via trigger context and mock registry.
  }

  @IsTest
  static void afterInsert_appendsRunningUserName() {
    // Set the plugin registry to use the custom plugin via direct caching.
    IHD_PluginRegistry.cachedConfigs = new Map<String, List<IHD_Plugin__mdt>>{
      'TRIGGER' => new List<IHD_Plugin__mdt>{
        new IHD_Plugin__mdt(
          DeveloperName = 'AppendUserToContext',
          Label = 'Append User to Context',
          PluginType__c = 'TRIGGER',
          ApexClassName__c = 'IHD_AppendUserToContextTriggerPlugin',
          Enabled__c = true,
          DisplayOrder__c = 1,
          SObjectType__c = 'Integration_Log__c'
        )
      }
    };

    IHD_PluginRegistry.cachedInstances = new Map<String, Object>{
      'IHD_AppendUserToContextTriggerPlugin' => new IHD_AppendUserToContextTriggerPlugin()
    };

    IHD_AppendUserToContextTriggerPlugin.reset();

    User u = [
      SELECT Id, Name
      FROM User
      WHERE IsActive = TRUE AND Profile.Name LIKE '%System Administrator%'
      LIMIT 1
    ];
    System.runAs(u) {
      Integration_Log__c log = new Integration_Log__c(
        IntegrationCode__c = 'TEST-PLUGIN',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Context__c = 'Initial Context',
        CorrelationId__c = 'CORR-PLUGIN-1'
      );
      insert log;

      log = [SELECT Context__c FROM Integration_Log__c WHERE Id = :log.Id];
      String expectedSuffix = ' | User: ' + UserInfo.getName();
      System.assert(
        log.Context__c.endsWith(expectedSuffix),
        'Context should have user suffix appended in INSERT via BEFORE trigger logic'
      );
      System.assert(
        log.Context__c.startsWith('Initial Context'),
        'Original context must be preserved before appended text'
      );
    }
  }

  @IsTest
  static void afterUpdate_doesNotDuplicateSuffix() {
    // Reuse the same plugin config.
    IHD_PluginRegistry.cachedConfigs = new Map<String, List<IHD_Plugin__mdt>>{
      'TRIGGER' => new List<IHD_Plugin__mdt>{
        new IHD_Plugin__mdt(
          DeveloperName = 'AppendUserToContext',
          Label = 'Append User to Context',
          PluginType__c = 'TRIGGER',
          ApexClassName__c = 'IHD_AppendUserToContextTriggerPlugin',
          Enabled__c = true,
          DisplayOrder__c = 1,
          SObjectType__c = 'Integration_Log__c'
        )
      }
    };

    IHD_PluginRegistry.cachedInstances = new Map<String, Object>{
      'IHD_AppendUserToContextTriggerPlugin' => new IHD_AppendUserToContextTriggerPlugin()
    };

    IHD_AppendUserToContextTriggerPlugin.reset();

    User u = [SELECT Id FROM User WHERE IsActive = TRUE LIMIT 1];
    System.runAs(u) {
      Integration_Log__c log = new Integration_Log__c(
        IntegrationCode__c = 'TEST-PLUGIN-2',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Context__c = 'Initial Context',
        CorrelationId__c = 'CORR-PLUGIN-2'
      );
      insert log;

      log.Context__c = 'Initial Context - updated';
      update log;

      log = [SELECT Context__c FROM Integration_Log__c WHERE Id = :log.Id];
      String expectedSuffix = ' | User: ' + UserInfo.getName();
      Integer suffixCount = String.isBlank(log.Context__c)
        ? 0
        : log.Context__c.split('User: ' + UserInfo.getName()).size() - 1;

      System.assertEquals(
        1,
        suffixCount,
        'User suffix should be applied only once after repeated operations'
      );
    }
  }
}
