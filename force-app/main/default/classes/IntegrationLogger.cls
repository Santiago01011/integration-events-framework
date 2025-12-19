/**
 * @description Generic utility for standardized integration logging using the framework's event publisher.
 * This is a minimal, framework-level logger. For business-specific message formatting,
 * extend or wrap this class in your org-specific code.
 */
public without sharing class IntegrationLogger {
    
    /**
     * @description Log a successful integration operation.
     * @param context The integration context (e.g., 'PedidosBatchJob')
     * @param message Human-readable success message
     * @param jobId The batch/job ID for correlation
     */
    public static void logSuccess(String context, String message, String jobId) {
        IntegrationEventPublisher.publishInfo(context, message, null, jobId);
    }
    
    /**
     * @description Log a successful integration operation with diagnostics.
     * @param context The integration context (e.g., 'PedidosBatchJob')
     * @param message Human-readable success message
     * @param diagnostics JSON or structured diagnostic data
     * @param jobId The batch/job ID for correlation
     */
    public static void logSuccess(String context, String message, String diagnostics, String jobId) {
        IntegrationEventPublisher.publishInfo(context, message, diagnostics, jobId);
    }
    
    /**
     * @description Log a failed integration operation.
     * @param context The integration context (e.g., 'PedidosBatchJob')
     * @param message Human-readable error message
     * @param jobId The batch/job ID for correlation
     */
    public static void logError(String context, String message, String jobId) {
        IntegrationEventPublisher.publishError(context, message, null, null, jobId);
    }
    
    /**
     * @description Log a failed integration operation with diagnostics.
     * @param context The integration context (e.g., 'PedidosBatchJob')
     * @param message Human-readable error message
     * @param diagnostics JSON or structured diagnostic data
     * @param jobId The batch/job ID for correlation
     */
    public static void logError(String context, String message, String diagnostics, String jobId) {
        IntegrationEventPublisher.publishError(context, message, diagnostics, null, jobId);
    }
}