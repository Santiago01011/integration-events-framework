@IsTest
private class IEF_MetadataUtilTest {
  @IsTest
  static void formatDeployError_returnsFallbackForNullResult() {
    Test.startTest();
    String message = IEF_MetadataUtil.formatDeployError(
      null,
      'Plugin deployment'
    );
    Test.stopTest();

    System.assertEquals(
      'Plugin deployment',
      message,
      'Null deploy result should return the fallback message'
    );
  }

  @IsTest
  static void formatDeployError_returnsStatusFallbackForCleanResult() {
    Metadata.DeployResult result = new Metadata.DeployResult();
    result.status = Metadata.DeployStatus.Succeeded;

    Test.startTest();
    String message = IEF_MetadataUtil.formatDeployError(
      result,
      'Plugin deployment'
    );
    Test.stopTest();

    System.assertEquals(
      'Plugin deployment failed with status: Succeeded',
      message,
      'Clean result should fall back to the status message'
    );
  }

  @IsTest
  static void formatDeployError_joinsGlobalAndComponentFailures() {
    Metadata.DeployResult result = new Metadata.DeployResult();
    result.status = Metadata.DeployStatus.Failed;
    result.errorMessage = 'Global Error';

    Metadata.DeployDetails details = new Metadata.DeployDetails();
    Metadata.DeployMessage failure = new Metadata.DeployMessage();
    failure.fullName = 'TestComponent';
    failure.problem = 'Component specific error';
    details.componentFailures = new List<Metadata.DeployMessage>{ failure };
    result.details = details;

    Test.startTest();
    String message = IEF_MetadataUtil.formatDeployError(
      result,
      'Integration Registry deployment'
    );
    Test.stopTest();

    System.assertEquals(
      'Integration Registry deployment failed: Global Error; [TestComponent] Component specific error',
      message,
      'Deploy errors should be joined from global and component failures'
    );
  }
}
