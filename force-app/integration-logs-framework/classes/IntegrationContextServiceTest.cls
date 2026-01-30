/**
 * @description Test class for IntegrationContextService.
 * Validates normalization logic using the Integration Registry.
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

  @IsTest
  static void testNormalizationWithRegisteredCode() {
    IntegrationContextService.setTestContextMappings(getMockMappings());

    Test.startTest();
    String result = IntegrationContextService.normalize('SAP_ORDERS');
    Test.stopTest();

    System.assertEquals(
      'ERP Systems',
      result,
      'Should return Group from registry'
    );
  }

  @IsTest
  static void testNormalizationCaseInsensitive() {
    IntegrationContextService.setTestContextMappings(getMockMappings());

    Test.startTest();
    String result = IntegrationContextService.normalize('sap_orders');
    Test.stopTest();

    System.assertEquals(
      'ERP Systems',
      result,
      'Should match case-insensitively'
    );
  }

  @IsTest
  static void testNormalizationUnregisteredCode() {
    IntegrationContextService.setTestContextMappings(getMockMappings());

    Test.startTest();
    String result = IntegrationContextService.normalize('UNKNOWN_INTEGRATION');
    Test.stopTest();

    System.assertEquals(
      'UNKNOWN_INTEGRATION',
      result,
      'Should return original code if not registered'
    );
  }

  @IsTest
  static void testNormalizationNullInput() {
    IntegrationContextService.setTestContextMappings(getMockMappings());

    Test.startTest();
    String result = IntegrationContextService.normalize(null);
    Test.stopTest();

    System.assertEquals(
      'Unregistered',
      result,
      'Null input should return Unregistered'
    );
  }

  @IsTest
  static void testNormalizationEmptyInput() {
    IntegrationContextService.setTestContextMappings(getMockMappings());

    Test.startTest();
    String result = IntegrationContextService.normalize('');
    Test.stopTest();

    System.assertEquals(
      'Unregistered',
      result,
      'Empty input should return Unregistered'
    );
  }

  @IsTest
  static void testNormalizationDecisionTree() {
    Map<String, String> map1 = new Map<String, String>{ 'CODE1' => 'GroupX' };
    IntegrationContextService.setTestContextMappings(map1);
    System.assertEquals('GroupX', IntegrationContextService.normalize('CODE1'));
  }

  @IsTest
  static void testNormalizationWithoutMockMappings() {
    // This will hit the SOQL path in initializeRegistryMappings
    Test.startTest();
    String result = IntegrationContextService.normalize('ANY_CODE');
    Test.stopTest();
    System.assertNotEquals(null, result);
  }
}
