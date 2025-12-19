/**
 * @description Batch Apex class for synchronizing Invoices and Invoice Lines from SAP B1 with pagination.
 * Handles multi-database integration with scalable callouts and proper error handling.
 * Uses Database.Stateful to accumulate invoices across pages and delegates to FacturasController for processing.
 * Implements Database.RaisesPlatformEvents to ensure BatchApexErrorEvent is published on uncaught exceptions.
 * 
 * Uses BatchIntegrationHelper for unified error handling, mock mode support, and diagnostics.
 */
public class FacturasBatchJob implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful, Database.RaisesPlatformEvents {
    private String baseURL;
    private String dbName;
    private String username;
    private String password;
    private String mockPayload;
    
    private List<Map<String, Object>> accumulatedInvoices = new List<Map<String, Object>>();
    private BatchIntegrationHelper.BatchContext batchCtx;
    private FacturasController.ProcessResult processingResult = null;
    
    public FacturasBatchJob(String baseURL, String dbName, String username, String password) {
        this(baseURL, dbName, username, password, null);
    }
    
    public FacturasBatchJob(String baseURL, String dbName, String username, String password, String mockPayload) {
        this.baseURL = baseURL;
        this.dbName = dbName;
        this.username = username;
        this.password = password;
        this.mockPayload = mockPayload;
        
        this.batchCtx = BatchIntegrationHelper.createContext('Facturas Integration', dbName);
        
        Object mockData = BatchIntegrationHelper.parseMockPayload(mockPayload, batchCtx);
        if (mockData instanceof List<Object>) {
            for (Object obj : (List<Object>) mockData) {
                accumulatedInvoices.add((Map<String, Object>) obj);
            }
        }
    }
    
    public Iterable<String> start(Database.BatchableContext bc) {
        if (batchCtx.mode == BatchIntegrationHelper.MODE_MOCK) {
            return new List<String>{ 'process' };
        }
        return new List<String>{ 'start' };
    }
    
    public void execute(Database.BatchableContext bc, List<String> scope) {        
        String jobId = bc != null ? String.valueOf(bc.getJobId()) : null;
        
        if (batchCtx.mode == BatchIntegrationHelper.MODE_MOCK) {
            processFacturas(accumulatedInvoices, jobId);
            return;
        }
        
        String expandValue = 'Invoices($select=DocEntry,DocNum,FolioNumber,DocDate,DocDueDate,DocCurrency,U_SEI_FEBOSID,DocType,Address,Address2,ShipToCode,NumAtCard,DocTotal,SalesPersonCode,Comments,U_Receta,U_SEI_IDW,CardCode),Invoices/DocumentLines($select=LineNum,ItemCode,ItemDescription,Quantity,ShipDate,Price,PriceAfterVAT,WarehouseCode,BarCode,TaxCode)';
        String filterValue = 'Invoices/DocEntry eq Invoices/DocumentLines/DocEntry and Invoices/UpdateDate gt \'2025-08-01\'';
        String encodedExpand = EncodingUtil.urlEncode(expandValue, 'UTF-8');
        String encodedFilter = EncodingUtil.urlEncode(filterValue, 'UTF-8');
        String resourcePath = '/$crossjoin(Invoices,Invoices/DocumentLines)?$expand=' + encodedExpand + '&$filter=' + encodedFilter;
        
        List<Map<String, Object>> fetchedData = BatchIntegrationHelper.fetchLiveData(
            this.baseURL,
            this.dbName,
            this.username,
            this.password,
            resourcePath,
            batchCtx
        );
        
        if (!fetchedData.isEmpty()) {
            accumulatedInvoices.addAll(fetchedData);
        }
        
        if (!accumulatedInvoices.isEmpty()) {
            processFacturas(accumulatedInvoices, jobId);
        }
    }
    
    public void finish(Database.BatchableContext bc) {        
        String jobId = bc != null ? String.valueOf(bc.getJobId()) : null;
        
        Map<String, Object> processingData = new Map<String, Object>();
        
        if (processingResult != null) {
            processingData.put('invoicesProcessed', processingResult.invoicesProcessed);
            processingData.put('invoicesUpserted', processingResult.invoicesUpserted);
            processingData.put('linesProcessed', processingResult.linesProcessed);
            processingData.put('linesUpserted', processingResult.linesUpserted);
            
            if (processingResult.invoicesSkipped > 0) {
                processingData.put('invoicesSkipped', processingResult.invoicesSkipped);
            }
            if (processingResult.linesSkipped > 0) {
                processingData.put('linesSkipped', processingResult.linesSkipped);
            }
            if (!processingResult.skippedInvoiceDetails.isEmpty()) {
                processingData.put('skippedInvoices', processingResult.skippedInvoiceDetails);
            }
            if (!processingResult.skippedLineDetails.isEmpty()) {
                processingData.put('skippedLines', processingResult.skippedLineDetails);
            }
            if (!processingResult.invoiceErrors.isEmpty()) {
                processingData.put('invoiceErrors', processingResult.invoiceErrors);
            }
            if (!processingResult.lineErrors.isEmpty()) {
                processingData.put('lineErrors', processingResult.lineErrors);
            }
        } else {
            processingData.put('invoicesProcessed', 0);
            processingData.put('invoicesUpserted', 0);
            processingData.put('linesProcessed', 0);
            processingData.put('linesUpserted', 0);
        }
        
        Map<String, Object> summary = BatchIntegrationHelper.buildDiagnosticSummary(batchCtx, processingData);
        
        Boolean hasIssues = BatchIntegrationHelper.hasSignificantIssues(batchCtx, processingData);
        
        if (hasIssues) {
            IntegrationLogger.logError('Facturas Integration', summary, jobId);
        } else {
            IntegrationLogger.logSuccess('Facturas Integration', summary, jobId);
        }
    }
    
    private void processFacturas(List<Map<String, Object>> invoiceNodes, String jobId) {
        try {
            this.processingResult = FacturasController.processInvoiceList(invoiceNodes, jobId);
        } catch (Exception ex) {
            batchCtx.rootCauseError = 'Exception in FacturasController: ' + ex.getMessage();
            batchCtx.errorStackTrace = ex.getStackTraceString();
        }
    }
}
