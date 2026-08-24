/**
 * @description Service class for managing integration registrations and metadata.
 */
public with sharing class IntegrationRegistryService {
  /**
   * @description Deploys a new or updated Integration Definition custom metadata record.
   */
  public static String deployRegistryEntry(
    String integrationCode,
    String label,
    String groupName,
    String direction,
    String transport,
    Boolean isEnabled
  ) {
    if (
      !Test.isRunningTest() &&
      !FeatureManagement.checkPermission('IEF_Manage_Plugins')
    ) {
      throw new AuraHandledException('Insufficient permissions');
    }
    if (String.isBlank(integrationCode)) {
      throw new AuraHandledException('Integration Code is required.');
    }

    try {
      String developerName = sanitizeDeveloperName(integrationCode);

      Metadata.CustomMetadata customMd = new Metadata.CustomMetadata();
      customMd.fullName = 'idhIntegration_Definition__mdt.' + developerName;
      customMd.label = label;

      Metadata.CustomMetadataValue codeField = new Metadata.CustomMetadataValue();
      codeField.field = 'IntegrationCode__c';
      codeField.value = integrationCode;
      customMd.values.add(codeField);

      Metadata.CustomMetadataValue labelField = new Metadata.CustomMetadataValue();
      labelField.field = 'Label__c';
      labelField.value = label;
      customMd.values.add(labelField);

      if (String.isNotBlank(groupName)) {
        Metadata.CustomMetadataValue groupField = new Metadata.CustomMetadataValue();
        groupField.field = 'Group__c';
        groupField.value = groupName;
        customMd.values.add(groupField);
      }

      if (String.isNotBlank(direction)) {
        Metadata.CustomMetadataValue directionField = new Metadata.CustomMetadataValue();
        directionField.field = 'Direction__c';
        directionField.value = direction;
        customMd.values.add(directionField);
      }

      if (String.isNotBlank(transport)) {
        Metadata.CustomMetadataValue transportField = new Metadata.CustomMetadataValue();
        transportField.field = 'Transport__c';
        transportField.value = transport;
        customMd.values.add(transportField);
      }

      Metadata.CustomMetadataValue enabledField = new Metadata.CustomMetadataValue();
      enabledField.field = 'Enabled__c';
      enabledField.value = isEnabled == null ? true : isEnabled;
      customMd.values.add(enabledField);

      Metadata.DeployContainer container = new Metadata.DeployContainer();
      container.addMetadata(customMd);

      Id jobId;
      if (Test.isRunningTest()) {
        jobId = '0Af000000000001AAA';
      } else {
        jobId = Metadata.Operations.enqueueDeployment(
          container,
          new RegistryDeployCallback()
        );
      }
      String syncValue = String.isNotBlank(groupName) ? groupName : label;
      syncHistoricalLogsFuture(integrationCode, syncValue);

      return String.valueOf(jobId);
    } catch (Exception e) {
      IntegrationEventPublisher.handleControllerError(e);
      return null;
    }
  }

  /**
   * @description Sanitizes an integration code into a valid Custom Metadata API name.
   * Rules: alphanumeric + underscores, must start with letter, no trailing underscore,
   * no consecutive underscores, max 40 characters.
   */
  private static String sanitizeDeveloperName(String input) {
    if (String.isBlank(input)) {
      return 'Unknown';
    }
    String sanitized = input.replaceAll('[^a-zA-Z0-9_]', '_');
    while (sanitized.contains('__')) {
      sanitized = sanitized.replace('__', '_');
    }
    while (sanitized.length() > 0 && !sanitized.substring(0, 1).isAlpha()) {
      sanitized = sanitized.substring(1);
    }
    while (sanitized.length() > 0 && sanitized.endsWith('_')) {
      sanitized = sanitized.substring(0, sanitized.length() - 1);
    }
    if (String.isBlank(sanitized)) {
      sanitized = 'Int_' + String.valueOf(System.currentTimeMillis()).right(10);
    }
    if (sanitized.length() > 40) {
      sanitized = sanitized.substring(0, 40);
      while (sanitized.endsWith('_')) {
        sanitized = sanitized.substring(0, sanitized.length() - 1);
      }
    }
    return sanitized;
  }

  /**
   * @description Updates historical logs in the background.
   */
  @future
  public static void syncHistoricalLogsFuture(
    String integrationCode,
    String normalizedValue
  ) {
    List<Integration_Log__c> logs = [
      SELECT Id, Normalized_Context__c
      FROM Integration_Log__c
      WHERE IntegrationCode__c = :integrationCode
      LIMIT 5000
    ];

    if (!logs.isEmpty()) {
      for (Integration_Log__c log : logs) {
        log.Normalized_Context__c = normalizedValue;
      }
      update as system logs;
    }
  }

  /**
   * @description Callback for metadata deployments.
   */
  public class RegistryDeployCallback implements Metadata.DeployCallback {
    public void handleResult(
      Metadata.DeployResult result,
      Metadata.DeployCallbackContext context
    ) {
      if (result.status != Metadata.DeployStatus.Succeeded) {
        String message = buildErrorMessage(result);
        IntegrationEventPublisher.handleControllerError(message);
      }
    }

    private String buildErrorMessage(Metadata.DeployResult result) {
      List<String> errorParts = new List<String>();

      if (String.isNotBlank(result.errorMessage)) {
        errorParts.add(result.errorMessage);
      }

      if (result.details != null && result.details.componentFailures != null) {
        for (
          Metadata.DeployMessage failure : result.details.componentFailures
        ) {
          String componentError = '';
          if (String.isNotBlank(failure.fullName)) {
            componentError += '[' + failure.fullName + '] ';
          }
          if (String.isNotBlank(failure.problem)) {
            componentError += failure.problem;
          }
          if (String.isNotBlank(componentError)) {
            errorParts.add(componentError);
          }
        }
      }

      if (errorParts.isEmpty()) {
        return 'Integration Registry deployment failed with status: ' +
          result.status;
      }

      return 'Integration Registry deployment failed: ' +
        String.join(errorParts, '; ');
    }
  }
}
