/**
 * @description Utility for formatting Metadata API deployment errors.
 * Shared by deploy callbacks so failure messages stay consistent across the framework.
 */
public with sharing class IEF_MetadataUtil {
  /**
   * @description Builds a human-readable message from a Metadata.DeployResult,
   * combining the global error message with any component failures.
   * @param deployResult The deployment result to inspect
   * @param fallbackMessage Label prepended to the failure message (e.g. 'Plugin deployment')
   * @return The formatted error message
   */
  public static String formatDeployError(
    Object deployResult,
    String fallbackMessage
  ) {
    if (deployResult == null) {
      return fallbackMessage;
    }
    Metadata.DeployResult result = (Metadata.DeployResult) deployResult;
    List<String> errorParts = new List<String>();

    if (String.isNotBlank(result.errorMessage)) {
      errorParts.add(result.errorMessage);
    }

    if (result.details != null && result.details.componentFailures != null) {
      for (Metadata.DeployMessage failure : result.details.componentFailures) {
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
      return fallbackMessage + ' failed with status: ' + result.status;
    }

    return fallbackMessage + ' failed: ' + String.join(errorParts, '; ');
  }
}
