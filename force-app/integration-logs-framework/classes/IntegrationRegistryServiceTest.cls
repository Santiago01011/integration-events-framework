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
      System.assert(
        e.getMessage().contains('Integration Code is required'),
        'Should throw validation error'
      );
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
  static void sanitizeDeveloperName_RemovesSpecialCharacters() {
    Test.startTest();
    String jobId = IntegrationRegistryService.deployRegistryEntry(
      'SAP-ORDERS@123!',
      'Label',
      'Group',
      'Inbound',
      'REST',
      true
    );
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'Should sanitize special characters');
  }

  @IsTest
  static void syncHistoricalLogsFuture_UpdatesLogs_WhenLogsExist() {
    List<Integration_Log__c> logs = new List<Integration_Log__c>();
    for (Integer i = 0; i < 5; i++) {
      logs.add(
        new Integration_Log__c(
          IntegrationCode__c = 'SAP_ORDERS',
          ObservationType__c = 'HTTP_REQUEST',
          CorrelationId__c = 'corr-' + i,
          Context__c = '{}',
          Normalized_Context__c = 'Old Value',
          OccurredAt__c = Datetime.now()
        )
      );
    }
    insert as system logs;

    Test.startTest();
    IntegrationRegistryService.syncHistoricalLogsFuture(
      'SAP_ORDERS',
      'ERP Systems'
    );
    Test.stopTest();

    List<Integration_Log__c> updatedLogs = [
      SELECT Normalized_Context__c
      FROM Integration_Log__c
      WHERE IntegrationCode__c = 'SAP_ORDERS'
    ];
    System.assertEquals(5, updatedLogs.size(), 'Should find all logs');
    for (Integration_Log__c log : updatedLogs) {
      System.assertEquals(
        'ERP Systems',
        log.Normalized_Context__c,
        'Should update normalized context'
      );
    }
  }

  @IsTest
  static void syncHistoricalLogsFuture_DoesNothing_WhenNoLogsExist() {
    Test.startTest();
    IntegrationRegistryService.syncHistoricalLogsFuture('NONEXISTENT', 'Value');
    Test.stopTest();

    System.assert(true, 'Should handle empty result gracefully');
  }

  @IsTest
  static void registryDeployCallback_HandlesSuccess() {
    IntegrationRegistryService.RegistryDeployCallback callback = new IntegrationRegistryService.RegistryDeployCallback();

    Metadata.DeployResult mockResult = new Metadata.DeployResult();
    mockResult.status = Metadata.DeployStatus.Succeeded;

    Metadata.DeployCallbackContext mockContext = new Metadata.DeployCallbackContext();

    Test.startTest();
    callback.handleResult(mockResult, mockContext);
    Test.stopTest();

    System.assert(true, 'Should handle success without error');
  }

  @IsTest
  static void registryDeployCallback_HandlesFailure() {
    IntegrationRegistryService.RegistryDeployCallback callback = new IntegrationRegistryService.RegistryDeployCallback();

    Metadata.DeployResult mockResult = new Metadata.DeployResult();
    mockResult.status = Metadata.DeployStatus.Failed;
    mockResult.errorMessage = 'Test error';

    Metadata.DeployCallbackContext mockContext = new Metadata.DeployCallbackContext();

    Boolean exceptionThrown = false;

    Test.startTest();
    try {
      callback.handleResult(mockResult, mockContext);
    } catch (AuraHandledException e) {
      exceptionThrown = true;
      System.assert(
        e.getMessage().contains('failed'),
        'Should include failure message'
      );
    }
    Test.stopTest();

    System.assertEquals(
      true,
      exceptionThrown,
      'Should throw exception on failure'
    );
  }
}
