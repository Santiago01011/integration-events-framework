/**
 * @description Test class for IntegrationContextService.
 * Validates normalization logic using the Integration Registry.
 *
 * NOTE: testAaa_InitializationWithRealCMDT runs first (alphabetically) to ensure
 * the SOQL initialization path is exercised.
 */
@IsTest
private class IntegrationContextServiceTest {
  /**
   * @description Creates mock registry mappings for test isolation.
   * @return Map of IntegrationCode to Group/Label
   */
  private static Map<String, String> getMockMappings() {
    return new Map<String, String>{
      'SAP_ORDERS' => 'ERP Systems',
      'SF_CONTACTS' => 'CRM'
    };
  }

  /**
   * @description Exercises the SOQL initialization path (non-mocked).
   */
  @IsTest
  static void testAaa_InitializationWithRealCMDT() {
    IntegrationContextService.registryMappings = null;
    IntegrationContextService.mockDefinitions = null;

    Test.startTest();
    String result = IntegrationContextService.normalize('SOME_CODE');
    Test.stopTest();

    System.assertNotEquals(null, result);
  }

  /**
   * @description Specifically exercises the Group/Label fallback logic in initializeRegistryMappings
   * using injected CMDT mock records. This is the "special way" to test CMDT logic.
   */
  @IsTest
  static void testInitializationFallbackLogic() {
    IntegrationContextService.registryMappings = null;

    List<idhIntegration_Definition__mdt> mocks = new List<idhIntegration_Definition__mdt>();

    mocks.add(
      (idhIntegration_Definition__mdt) JSON.deserialize(
        '{"IntegrationCode__c":"CODE_G", "Group__c":"GroupVal", "Label__c":"LabelVal", "Enabled__c":true}',
        idhIntegration_Definition__mdt.class
      )
    );

    mocks.add(
      (idhIntegration_Definition__mdt) JSON.deserialize(
        '{"IntegrationCode__c":"CODE_L", "Group__c":null, "Label__c":"LabelOnly", "Enabled__c":true}',
        idhIntegration_Definition__mdt.class
      )
    );

    mocks.add(
      (idhIntegration_Definition__mdt) JSON.deserialize(
        '{"IntegrationCode__c":"CODE_C", "Group__c":"", "Label__c":null, "Enabled__c":true}',
        idhIntegration_Definition__mdt.class
      )
    );

    IntegrationContextService.mockDefinitions = mocks;

    Test.startTest();
    String resG = IntegrationContextService.normalize('CODE_G');
    String resL = IntegrationContextService.normalize('CODE_L');
    String resC = IntegrationContextService.normalize('CODE_C');
    Test.stopTest();

    System.assertEquals('GroupVal', resG, 'Should use Group if populated');
    System.assertEquals(
      'LabelOnly',
      resL,
      'Should fallback to Label if Group is blank'
    );
    System.assertEquals(
      'CODE_C',
      resC,
      'Should fallback to Code if Group and Label are blank'
    );
  }

  @IsTest
  static void testNormalizationWithRegisteredCode() {
    IntegrationContextService.setTestContextMappings(getMockMappings());

    Test.startTest();
    String result = IntegrationContextService.normalize('SAP_ORDERS');
    Test.stopTest();

    System.assertEquals('ERP Systems', result);
  }

  @IsTest
  static void testNormalizationCaseInsensitive() {
    IntegrationContextService.setTestContextMappings(getMockMappings());

    Test.startTest();
    String result = IntegrationContextService.normalize('sap_orders');
    Test.stopTest();

    System.assertEquals('ERP Systems', result);
  }

  @IsTest
  static void testNormalizationUnregisteredCode() {
    IntegrationContextService.setTestContextMappings(getMockMappings());

    Test.startTest();
    String result = IntegrationContextService.normalize('UNKNOWN');
    Test.stopTest();

    System.assertEquals('UNKNOWN', result);
  }

  @IsTest
  static void testNormalizationNullOrEmpty() {
    IntegrationContextService.setTestContextMappings(getMockMappings());

    System.assertEquals(
      'Unregistered',
      IntegrationContextService.normalize(null)
    );
    System.assertEquals(
      'Unregistered',
      IntegrationContextService.normalize('')
    );
  }
}
