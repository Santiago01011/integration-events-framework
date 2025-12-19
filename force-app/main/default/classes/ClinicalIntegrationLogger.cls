/**
 * @description Org-specific integration logger for Clinical.
 * Provides business-specific message formatting and diagnostic aggregation
 * for orders, products, and invoices integrations.
 */
public without sharing class ClinicalIntegrationLogger {
    
    /**
     * @description Log a successful integration batch with rich diagnostics.
     * @param context The integration context (e.g., 'PedidosBatchJob')
     * @param summary Map containing integration-specific diagnostic information
     * @param jobId The batch job ID for correlation
     */
    public static void logSuccess(String context, Map<String, Object> summary, String jobId) {
        String message = buildHumanReadableMessage(summary, false);
        String diagnostics = buildJsonDiagnostics(summary);
        IntegrationEventPublisher.publishInfo(context, message, diagnostics, jobId);
    }
    
    /**
     * @description Log a failed integration batch with root cause analysis.
     * @param context The integration context (e.g., 'PedidosBatchJob')
     * @param summary Map containing integration-specific diagnostic information
     * @param jobId The batch job ID for correlation
     */
    public static void logError(String context, Map<String, Object> summary, String jobId) {
        String message = buildHumanReadableMessage(summary, true);
        if (summary.containsKey('rootCauseError')) {
            message += '\n\nROOT_CAUSE: ' + summary.get('rootCauseError');
        }
        String diagnostics = buildJsonDiagnostics(summary);
        IntegrationEventPublisher.publishError(context, message, diagnostics, jobId);
    }
    
    /**
     * @description Build a human-readable message from the summary map.
     * Handles metrics for Orders, Products, and Invoices integrations.
     * @param summary The diagnostic summary map
     * @param isError Whether this is an error message
     * @return Formatted human-readable message
     */
    private static String buildHumanReadableMessage(Map<String, Object> summary, Boolean isError) {
        String status = isError ? '❌ FAILED' : '✅ SUCCESS';
        String integration = (String) summary.get('integration');
        String database = (String) summary.get('database');
        String mode = (String) summary.get('mode');
        
        String msg = status + ' - ' + integration;
        if (database != null) msg += '\nDatabase: ' + database;
        if (mode != null) msg += ' | Mode: ' + mode;
        
        if (summary.containsKey('totalOrders')) {
            msg += buildOrdersMetrics(summary, isError);
        } else if (summary.containsKey('totalProducts')) {
            msg += buildProductsMetrics(summary);
        } else if (summary.containsKey('totalInvoices')) {
            msg += buildInvoicesMetrics(summary);
        }
        
        return msg;
    }
    
    /**
     * @description Build Orders integration metrics section.
     * @param summary The diagnostic summary map
     * @param isError Whether this is an error context
     * @return Formatted orders metrics string
     */
    private static String buildOrdersMetrics(Map<String, Object> summary, Boolean isError) {
        String msg = '';
        Integer totalOrders = (Integer) summary.get('totalOrders');
        Integer totalPages = (Integer) summary.get('totalPages');
        Integer ordersProcessed = (Integer) summary.get('ordersProcessed');
        Integer ordersUpserted = (Integer) summary.get('ordersUpserted');
        Integer linesUpserted = (Integer) summary.get('linesUpserted');
        
        if (totalOrders > 0 || totalPages != null) {
            msg += '\nBatch: ' + totalOrders + ' orders from ' + totalPages + ' pages';
        }
        
        if (ordersProcessed != null && ordersProcessed > 0) {
            msg += '\nProcessing: ';
            List<String> results = new List<String>();
            
            if (ordersUpserted != null && ordersUpserted > 0) {
                results.add('Upserted ' + ordersUpserted + ' orders');
            }
            if (linesUpserted != null && linesUpserted > 0) {
                results.add(linesUpserted + ' lines');
            }
            
            Integer ordersSkipped = (Integer) summary.get('ordersSkipped');
            Integer linesSkipped = (Integer) summary.get('linesSkipped');
            if (ordersSkipped != null && ordersSkipped > 0) {
                results.add('⚠️ Skipped ' + ordersSkipped + ' orders');
            }
            if (linesSkipped != null && linesSkipped > 0) {
                results.add(linesSkipped + ' lines');
            }
            
            Integer rejectedCount = summary.get('rejectedRawOrders') != null ? 
                ((List<Object>) summary.get('rejectedRawOrders')).size() : 0;
            if (rejectedCount > 0 && !isError) {
                results.add('ℹ️ ' + rejectedCount + ' rejected (duplicates/constraints)');
            }
            msg += String.join(results, ' | ');
        }
        
        return msg;
    }
    
    /**
     * @description Build Products integration metrics section.
     * @param summary The diagnostic summary map
     * @return Formatted products metrics string
     */
    private static String buildProductsMetrics(Map<String, Object> summary) {
        String msg = '';
        Integer totalProducts = (Integer) summary.get('totalProducts');
        Integer productsUpserted = (Integer) summary.get('productsUpserted');
        Integer productsSkipped = (Integer) summary.get('productsSkipped');
        
        msg += '\nTotal: ' + totalProducts + ' products';
        
        List<String> results = new List<String>();
        if (productsUpserted != null && productsUpserted > 0) {
            results.add('Upserted ' + productsUpserted);
        }
        if (productsSkipped != null && productsSkipped > 0) {
            results.add('Skipped ' + productsSkipped);
        }
        
        if (!results.isEmpty()) {
            msg += ' | ' + String.join(results, ' | ');
        }
        
        return msg;
    }
    
    /**
     * @description Build Invoices integration metrics section.
     * @param summary The diagnostic summary map
     * @return Formatted invoices metrics string
     */
    private static String buildInvoicesMetrics(Map<String, Object> summary) {
        String msg = '';
        Integer totalInvoices = (Integer) summary.get('totalInvoices');
        Integer invoicesUpserted = (Integer) summary.get('invoicesUpserted');
        Integer invoicesSkipped = (Integer) summary.get('invoicesSkipped');
        
        msg += '\nTotal: ' + totalInvoices + ' invoices';
        
        List<String> results = new List<String>();
        if (invoicesUpserted != null && invoicesUpserted > 0) {
            results.add('Upserted ' + invoicesUpserted);
        }
        if (invoicesSkipped != null && invoicesSkipped > 0) {
            results.add('Skipped ' + invoicesSkipped);
        }
        
        if (!results.isEmpty()) {
            msg += ' | ' + String.join(results, ' | ');
        }
        
        return msg;
    }
    
    /**
     * @description Build JSON diagnostics string from the summary.
     * @param summary The diagnostic summary map
     * @return JSON string of diagnostics
     */
    private static String buildJsonDiagnostics(Map<String, Object> summary) {
        return JSON.serialize(summary);
    }
}
