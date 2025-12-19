/**
 * @description Abstract base class implementing the "State-Chaining Batch" pattern.
 * Handles paginated API calls by processing one page at a time and re-enqueuing itself
 * until all pages are processed. Uses Database.Stateful to maintain state across pages.
 * 
 * Subclasses must implement:
 * - getIntegrationLabel(): Return the integration name for logging
 * - getInitialResourcePath(): Build the initial OData query URL
 * - processPageData(): Process the fetched data for this page
 * - updateSummaryFromResult(): Update BatchSummary with processing results
 * 
 * Architecture:
 * 1. Queueable starts the chain by enqueuing this batch with batch size = 1
 * 2. start() returns one item to force execute() to run once per page
 * 3. execute() fetches ONE page, processes it, saves nextLink in stateful var
 * 4. finish() checks if nextLink exists:
 *    - If yes: re-enqueues via Queueable to process next page
 *    - If no: logs final consolidated summary
 */
public abstract class BasePaginatedBatchJob implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful, Database.RaisesPlatformEvents {
    
    protected String baseURL;
    protected String companyDB;
    protected String username;
    protected String password;
    
    protected String lastSyncDateStr;
    protected String resourceOrNextLink;
    protected String nextLinkForFinish;
    protected String mockPayload;
    
    protected BatchSummary summary;
    protected BatchIntegrationHelper.BatchContext batchCtx;
    
    /**
     * @description Constructor for live API calls (first call in chain).
     * @param baseURL SAP B1 Service Layer base URL
     * @param companyDB CompanyDB name
     * @param username SAP B1 username
     * @param password SAP B1 password
     * @param lastSyncDateStr Date filter for delta sync (e.g., '2025-08-01')
     */
    public BasePaginatedBatchJob(
        String baseURL,
        String companyDB,
        String username,
        String password,
        String lastSyncDateStr
    ) {
        this(baseURL, companyDB, username, password, lastSyncDateStr, null, null, null);
    }
    
    /**
     * @description Full constructor for chaining with state.
     * @param baseURL SAP B1 Service Layer base URL
     * @param companyDB CompanyDB name
     * @param username SAP B1 username
     * @param password SAP B1 password
     * @param lastSyncDateStr Date filter for delta sync
     * @param nextLink The odata.nextLink from previous page (null for first page)
     * @param summary Accumulated BatchSummary from previous pages (null for first page)
     * @param mockPayload Optional mock JSON payload for testing
     */
    public BasePaginatedBatchJob(
        String baseURL,
        String companyDB,
        String username,
        String password,
        String lastSyncDateStr,
        String nextLink,
        BatchSummary summary,
        String mockPayload
    ) {
        this.baseURL = baseURL;
        this.companyDB = companyDB;
        this.username = username != null ? username : Label.USUARIO_INT;
        this.password = password;
        this.lastSyncDateStr = lastSyncDateStr;
        this.resourceOrNextLink = nextLink;
        this.nextLinkForFinish = null;
        this.mockPayload = mockPayload;
        
        this.summary = (summary != null) ? summary : new BatchSummary();
        this.batchCtx = BatchIntegrationHelper.createContext(getIntegrationLabel(), companyDB);
        
        if (String.isNotBlank(mockPayload)) {
            BatchIntegrationHelper.parseMockPayload(mockPayload, batchCtx);
        }
    }
    
    /**
     * @description Returns the integration label for logging.
     * @return Integration name (e.g., 'Productos Integration')
     */
    protected abstract String getIntegrationLabel();
    
    /**
     * @description Builds the initial OData resource path for the first page.
     * Should include $expand, $filter, and any other query parameters.
     * @return The initial resource path string
     */
    protected abstract String getInitialResourcePath();
    
    /**
     * @description Processes the data fetched from a single page.
     * @param pageData List of records from the current page
     * @param jobId Current batch job ID
     * @return Processing result object (implementation-specific)
     */
    protected abstract Object processPageData(List<Map<String, Object>> pageData, String jobId);
    
    /**
     * @description Updates the BatchSummary with results from processing this page.
     * @param result The result object returned by processPageData
     */
    protected abstract void updateSummaryFromResult(Object result);
    
    /**
     * @description Builds the processing data map for final logging.
     * @return Map with processing metrics for IntegrationLogger
     */
    protected abstract Map<String, Object> buildProcessingData();
    
    /**
     * @description Creates a new instance of the concrete batch class for chaining.
     * Used by finish() to enqueue the next page.
     * @return New instance of the batch job with updated state
     */
    protected abstract BasePaginatedBatchJob createNextInstance();
    
    /**
     * @description Returns one item to force execute() to run once.
     */
    public Iterable<String> start(Database.BatchableContext bc) {
        if (batchCtx.mode == BatchIntegrationHelper.MODE_MOCK) {
            return new List<String>{ 'process_mock' };
        }
        return new List<String>{ 'fetch_one_page' };
    }
    
    /**
     * @description Fetches and processes a single page of data.
     * Sets nextLinkForFinish to determine if chain continues.
     */
    public void execute(Database.BatchableContext bc, List<String> scope) {
        String jobId = bc != null ? String.valueOf(bc.getJobId()) : null;
        
        if (batchCtx.mode == BatchIntegrationHelper.MODE_MOCK) {
            processMockData(jobId);
            return;
        }
        
        String resourcePath = determineResourcePath();
        
        try {
            SAPB1ApiService.PageResponse response = SAPB1ApiService.fetchOnePage(
                this.baseURL,
                this.companyDB,
                this.username,
                this.password,
                resourcePath,
                batchCtx
            );
            
            if (response.data != null && !response.data.isEmpty()) {
                Object result = processPageData(response.data, jobId);
                updateSummaryFromResult(result);
                this.summary.incrementPage();
                this.summary.incrementCallout();
            }
            
            this.nextLinkForFinish = response.nextLink;
            
        } catch (Exception ex) {
            batchCtx.rootCauseError = 'Exception in execute: ' + ex.getMessage();
            batchCtx.errorStackTrace = ex.getStackTraceString();
            this.summary.addError(ex.getMessage());
            this.nextLinkForFinish = null;
        }
    }
    
    /**
     * @description Orchestrates the chain: either continues to next page or logs final result.
     * 
     * @param bc Database.BatchableContext for job ID
     */
    public void finish(Database.BatchableContext bc) {
        String jobId = (bc != null) ? String.valueOf(bc.getJobId()) : null;
        Integer MAX_PAGES_FOR_CALL = 5; 
        Boolean hasMorePages = (this.nextLinkForFinish != null && batchCtx.mode != BatchIntegrationHelper.MODE_MOCK);
        Boolean hasHitPageLimit = (this.summary.totalPagesProcessed >= MAX_PAGES_FOR_CALL);
        if (hasMorePages && !hasHitPageLimit) {
            continueChain();
        } else {
            if (hasHitPageLimit && hasMorePages) {
                String stopMsg = 'SAFETY STOP: Reached call limit (' + MAX_PAGES_FOR_CALL + '). More data exists in SAP.';
                batchCtx.rootCauseError = stopMsg;
                this.summary.addError(stopMsg);
            }
            logFinalResult(jobId);
        }
    }
    
    /**
     * @description Determines which resource path to fetch (initial or nextLink).
     */
    private String determineResourcePath() {
        String path = (this.resourceOrNextLink != null) ? this.resourceOrNextLink : getInitialResourcePath();
        return path.startsWith('/') ? path : '/' + path;
    }
    
    /**
     * @description Processes mock data for testing.
     */
    private void processMockData(String jobId) {
        try {
            Object mockData = BatchIntegrationHelper.parseMockPayload(mockPayload, batchCtx);
            if (mockData instanceof List<Object>) {
                List<Map<String, Object>> dataList = new List<Map<String, Object>>();
                for (Object obj : (List<Object>) mockData) {
                    dataList.add((Map<String, Object>) obj);
                }
                Object result = processPageData(dataList, jobId);
                updateSummaryFromResult(result);
            }
        } catch (Exception ex) {
            batchCtx.rootCauseError = 'Mock processing error: ' + ex.getMessage();
            batchCtx.errorStackTrace = ex.getStackTraceString();
        }
        this.nextLinkForFinish = null;
    }
    
    /**
     * @description Enqueues the next batch in the chain via Queueable.
     * Subclasses must implement createNextInstance() to return a properly configured instance.
     */
    private void continueChain() {
        try {
            BasePaginatedBatchJob nextBatch = createNextInstance();
            System.enqueueJob(new PaginatedBatchStarter(nextBatch));
        } catch (Exception ex) {
            String errorMsg = 'Failed to continue chain: ' + ex.getMessage();
            batchCtx.rootCauseError = errorMsg;
            this.summary.addError(errorMsg);
            logFinalResult(null);
        }
    }

    /**
     * @description NEW: Public getter for the starter Queueable.
     * This is the new entry point for starting the chain.
     */
    public Queueable getStarter() {
        return new PaginatedBatchStarter(this);
    }
    
    /**
     * @description Logs the final consolidated result after all pages are processed.
     */
    private void logFinalResult(String jobId) {
        Map<String, Object> processingData = buildProcessingData();   
        processingData.put('totalPagesProcessed', this.summary.totalPagesProcessed);
        processingData.put('totalApiCallouts', this.summary.totalApiCallouts);
        if (!this.summary.errorMessages.isEmpty()) {
            processingData.put('chainErrors', this.summary.errorMessages);
        }
        Map<String, Object> diagnosticSummary = BatchIntegrationHelper.buildDiagnosticSummary(
            batchCtx,
            processingData
        );
        Boolean hasIssues = BatchIntegrationHelper.hasSignificantIssues(batchCtx, processingData);
        if (hasIssues) {
            IntegrationLogger.logError(getIntegrationLabel(), diagnosticSummary, jobId);
        } else {
            IntegrationLogger.logSuccess(getIntegrationLabel(), diagnosticSummary, jobId);
        }
    }
    
    /**
     * @description Inner Queueable class to start/continue the batch chain.
     * This is necessary because finish() cannot directly enqueue a new batch.
     */
    public class PaginatedBatchStarter implements Queueable, Database.AllowsCallouts {
        public BasePaginatedBatchJob batchToStart;
        public PaginatedBatchStarter(BasePaginatedBatchJob batch) {
            this.batchToStart = batch;
        }
        public void execute(QueueableContext context) {
            try {
                Database.executeBatch(this.batchToStart, 1);
            } catch (Exception ex) {
                IntegrationEventPublisher.publishError(
                    batchToStart.getIntegrationLabel(),
                    ex,
                    'Failed to enqueue next batch in chain',
                    context != null ? String.valueOf(context.getJobId()) : null
                );
            }
        }
    }
}
