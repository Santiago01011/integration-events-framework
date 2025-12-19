/**
 * Centralized utility for batch integration common operations.
 *
 * Responsibilities
 * - Mock mode detection and payload parsing.
 * - Live data fetching through SAPB1ApiService with pagination support.
 * - Error tracking (auth, transport, parsing) and consolidation.
 * - Building a compact, human-friendly diagnostic summary for unified logging.
 * - Severity heuristics to decide whether a run should be marked with issues.
 *
 * Consumers
 * - ProductosBatchJob, PedidosBatchJob, FacturasBatchJob (and future batches).
 *
 * Contracts
 * - Inputs: baseURL, database, username, password, resourcePath, and optional mockPayload.
 * - Outputs: accumulated records (List<Map<String,Object>>), BatchContext, and a summary Map.
 * - Error modes: returns empty lists on transport errors (tracks rootCauseError/errorStackTrace),
 *   never throws from helper methods to avoid breaking batch transactions.
 */
public class BatchIntegrationHelper {
    
    public static final String MODE_LIVE = 'LIVE';
    public static final String MODE_MOCK = 'MOCK';
    
    /**
     * Encapsulates execution context and diagnostic counters for a batch run.
     * Fields are intentionally generic to be reusable across integrations.
     */
    public class BatchContext {
        public String integration;
        public String mode;
        public String database;
        public Boolean authSuccess;
        public Integer totalPagesProcessed;
        public Integer totalRecordsProcessed;
        public Integer lastResponseStatus;
        public String lastResponseSnippet;
        public String rootCauseError;
        public String errorStackTrace;
        
        /**
         * Creates a new BatchContext.
         * @param integration Business-friendly integration name (e.g., 'Productos Integration').
         * @param database Source database identifier (e.g., 'X_PROFAR').
         */
        public BatchContext(String integration, String database) {
            this.integration = integration;
            this.database = database;
            this.mode = MODE_LIVE;
            this.authSuccess = false;
            this.totalPagesProcessed = 0;
            this.totalRecordsProcessed = 0;
        }
    }
    
    /**
     * Factory to create a new BatchContext.
     * @param integration Integration label.
     * @param database Database name.
     * @return Initialized BatchContext in LIVE mode.
     */
    public static BatchContext createContext(String integration, String database) {
        return new BatchContext(integration, database);
    }
    
    /**
     * Parses a raw mock JSON payload and switches the context to MOCK mode when valid.
     * Expected schema: { "value": [ ... nodes ... ] }
     * @param mockPayload Raw JSON string. If blank or invalid, returns null.
     * @param ctx BatchContext to mutate (mode, totals, errors).
     * @return List<Object> when valid with values; empty list if no values; null on parse error.
     */
    public static Object parseMockPayload(String mockPayload, BatchContext ctx) {
        if (String.isBlank(mockPayload)) {
            return null;
        }
        
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(mockPayload);
            List<Object> values = (List<Object>) root.get('value');
            
            if (values != null && !values.isEmpty()) {
                ctx.mode = MODE_MOCK;
                ctx.authSuccess = true;
                ctx.totalRecordsProcessed = values.size();
                return values;
            } else {
                ctx.rootCauseError = 'Mock payload has no values';
                return new List<Object>();
            }
        } catch (Exception ex) {
            ctx.rootCauseError = 'Mock payload parse error: ' + ex.getMessage();
            ctx.errorStackTrace = ex.getStackTraceString();
            return null;
        }
    }
    
    /**
     * Builds a compact summary map used by IntegrationLogger for consolidated logs.
     * Includes context (integration, database, mode, auth status, totals) + processing metrics.
     * @param ctx Current BatchContext.
     * @param processingResult Metrics map returned by controller processing.
     * @return Summary map suitable for human-readable message and optional JSON diagnostics.
     */
    public static Map<String, Object> buildDiagnosticSummary(
        BatchContext ctx,
        Map<String, Object> processingResult
    ) {
        Map<String, Object> summary = new Map<String, Object>();
        
        summary.put('integration', ctx.integration);
        summary.put('database', ctx.database);
        summary.put('mode', ctx.mode);
        summary.put('authSuccess', ctx.authSuccess);
        summary.put('totalPages', ctx.totalPagesProcessed);
        summary.put('totalRecords', ctx.totalRecordsProcessed);
        
        if (ctx.lastResponseStatus != null) {
            summary.put('lastResponseStatus', ctx.lastResponseStatus);
        }
        if (String.isNotBlank(ctx.lastResponseSnippet)) {
            summary.put('lastResponseSnippet', ctx.lastResponseSnippet);
        }
        
        if (processingResult != null) {
            summary.putAll(processingResult);
        }
        
        if (String.isNotBlank(ctx.rootCauseError)) {
            summary.put('rootCauseError', ctx.rootCauseError);
        }
        if (String.isNotBlank(ctx.errorStackTrace)) {
            summary.put('errorStackTrace', ctx.errorStackTrace);
        }
        
        return summary;
    }
    
    /**
     * Heuristic that flags a run as problematic based on context and processing metrics.
     * MOCK: only fails when no records are processed.
     * LIVE: fails on auth failure, zero records, data loss (lines lost), or collected errors/skips.
     * @param ctx Current BatchContext.
     * @param processingResult Metrics map from controller.
     * @return true when significant issues were detected.
     */
    public static Boolean hasSignificantIssues(
        BatchContext ctx,
        Map<String, Object> processingResult
    ) {
        if (ctx.mode == MODE_MOCK) {
            return ctx.totalRecordsProcessed == 0;
        }
        
        Boolean hasBatchIssues = !ctx.authSuccess || ctx.totalRecordsProcessed == 0;
        
        if (hasBatchIssues) {
            return true;
        }
        
        if (processingResult == null) {
            return false;
        }
        
        Boolean hasDataLoss = false;
        if (processingResult.containsKey('linesProcessed') && processingResult.containsKey('linesUpserted')) {
            Integer linesProcessed = (Integer) processingResult.get('linesProcessed');
            Integer linesUpserted = (Integer) processingResult.get('linesUpserted');
            Integer linesSkipped = processingResult.containsKey('linesSkipped') ? (Integer) processingResult.get('linesSkipped') : 0;
            
            if (linesProcessed > 0) {
                Integer linesLost = linesProcessed - linesUpserted - linesSkipped;
                if (linesLost > 0) {
                    hasDataLoss = true;
                }
            }
        }
        
        Boolean hasErrors = false;
        if (processingResult.containsKey('orderErrors')) {
            hasErrors = !((List<Object>) processingResult.get('orderErrors')).isEmpty();
        } else if (processingResult.containsKey('invoiceErrors')) {
            hasErrors = !((List<Object>) processingResult.get('invoiceErrors')).isEmpty();
        } else if (processingResult.containsKey('productErrors')) {
            hasErrors = !((List<Object>) processingResult.get('productErrors')).isEmpty();
        }
        
        Boolean hasSkips = false;
        if (processingResult.containsKey('ordersSkipped')) {
            hasSkips = (Integer) processingResult.get('ordersSkipped') > 0;
        } else if (processingResult.containsKey('invoicesSkipped')) {
            hasSkips = (Integer) processingResult.get('invoicesSkipped') > 0;
        } else if (processingResult.containsKey('productsSkipped')) {
            hasSkips = (Integer) processingResult.get('productsSkipped') > 0;
        }
        
        return hasDataLoss || hasErrors || hasSkips;
    }
}
