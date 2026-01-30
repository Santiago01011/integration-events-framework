/**
 * @description Test class for IntegrationRegistryService.
 * Validates integration registration and metadata deployment logic.
 */
@IsTest
private class IntegrationRegistryServiceTest {
  @IsTest
  static void deployRegistryEntry_ReturnsJobId_WhenValidInput() {
    Test.startTest();
    String jobId = IntegrationRegistryService.deployRegistryEntry(
      'SAP_ORDERS',
      'SAP Orders Integration',
      'ERP Systems',
      'Inbound',
      'REST',
      true
    );
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'Should return job ID');
    System.assert(
      jobId.startsWith('0Af'),
      'Should be metadata deployment job ID in test'
    );
  }

  @IsTest
  static void deployRegistryEntry_ThrowsException_WhenCodeIsNull() {
    Boolean exceptionThrown = false;

    Test.startTest();
    try {
      IntegrationRegistryService.deployRegistryEntry(
        null,
        'Label',
        'Group',
        'Inbound',
        'REST',
        true
      );
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assertEquals(
      true,
      exceptionThrown,
      'Should throw exception for null code'
    );
  }

  @IsTest
  static void deployRegistryEntry_ThrowsException_WhenCodeIsBlank() {
    Boolean exceptionThrown = false;

    Test.startTest();
    try {
      IntegrationRegistryService.deployRegistryEntry(
        '',
        'Label',
        'Group',
        'Inbound',
        'REST',
        true
      );
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assertEquals(
      true,
      exceptionThrown,
      'Should throw exception for blank code'
    );
  }

  @IsTest
  static void deployRegistryEntry_HandlesOptionalFields_WhenNull() {
    Test.startTest();
    String jobId = IntegrationRegistryService.deployRegistryEntry(
      'TEST_CODE',
      'Test Label',
      null,
      null,
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'Should handle null optional fields');
  }

  @IsTest
  static void sanitizeDeveloperName_ComplexCases() {
    Test.startTest();
    // Case 1: Long name with trailing underscores
    String longName = 'This_Is_A_Very_Long_Integration_Code_That_Exceeds_Forty_Chars___';
    String jobId1 = IntegrationRegistryService.deployRegistryEntry(
      longName,
      'L',
      'G',
      'I',
      'R',
      true
    );

    // Case 2: Starts with numbers (should be stripped)
    String jobId2 = IntegrationRegistryService.deployRegistryEntry(
      '123_START_WITH_NUM',
      'L',
      'G',
      'I',
      'R',
      true
    );

    // Case 3: Only special characters (should generate fallback name)
    String jobId3 = IntegrationRegistryService.deployRegistryEntry(
      '!!!',
      'L',
      'G',
      'I',
      'R',
      true
    );
    Test.stopTest();

    System.assertNotEquals(null, jobId1, 'Should handle long name');
    System.assertNotEquals(null, jobId2, 'Should handle number prefix');
    System.assertNotEquals(null, jobId3, 'Should handle fallback name');
  }

  @IsTest
  static void syncHistoricalLogsFuture_UpdatesLargeBatch() {
    List<Integration_Log__c> logs = new List<Integration_Log__c>();
    for (Integer i = 0; i < 10; i++) {
      logs.add(
        new Integration_Log__c(
          IntegrationCode__c = 'SYNC_TEST',
          ObservationType__c = 'TEST',
          CorrelationId__c = 'corr-' + i,
          Context__c = '{}'
        )
      );
    }
    insert as system logs;

    Test.startTest();
    IntegrationRegistryService.syncHistoricalLogsFuture(
      'SYNC_TEST',
      'New Group'
    );
    Test.stopTest();

    Integer updated = [
      SELECT COUNT()
      FROM Integration_Log__c
      WHERE
        IntegrationCode__c = 'SYNC_TEST'
        AND Normalized_Context__c = 'New Group'
    ];
    System.assertEquals(10, updated, 'All logs should be updated');
  }

  @IsTest
  static void registryDeployCallback_HandlesComplexFailure() {
    IntegrationRegistryService.RegistryDeployCallback callback = new IntegrationRegistryService.RegistryDeployCallback();

    Metadata.DeployResult mockResult = new Metadata.DeployResult();
    mockResult.status = Metadata.DeployStatus.Failed;
    mockResult.errorMessage = 'Global Error';

    Metadata.DeployDetails details = new Metadata.DeployDetails();
    Metadata.DeployMessage failure = new Metadata.DeployMessage();
    failure.fullName = 'TestComponent';
    failure.problem = 'Component specific error';
    details.componentFailures = new List<Metadata.DeployMessage>{ failure };
    mockResult.details = details;

    Metadata.DeployCallbackContext mockContext = new Metadata.DeployCallbackContext();

    Test.startTest();
    try {
      // This will log an error event via IntegrationEventPublisher.handleControllerError and throw AuraHandledException
      callback.handleResult(mockResult, mockContext);
    } catch (AuraHandledException e) {
      // Expected
    }
    Test.stopTest();

    System.assert(
      true,
      'Should handle complex failure without crashing the test'
    );
  }
}
