/**
 * @description Batch Apex class for synchronizing Orders and OrderItems from SAP B1 with pagination support.
 * Handles multi-database integration with scalable callouts and proper error handling.
 * Uses Database.Stateful to accumulate orders across pages and delegate to PedidosController for processing.
 * Implements Database.RaisesPlatformEvents to ensure BatchApexErrorEvent is published on uncaught exceptions.
 * 
 * Uses BatchIntegrationHelper for unified error handling, mock mode support, and diagnostics.
 */
public without sharing class PedidosBatchJob implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful, Database.RaisesPlatformEvents {
    private String baseURL;
    private String dbName;
    private String username;
    private String password;
    private String mockPayload;
    
    private List<Map<String, Object>> accumulatedOrders = new List<Map<String, Object>>();
    private BatchIntegrationHelper.BatchContext batchCtx;
    private PedidosController.ProcessResult processingResult = null;
    
    public PedidosBatchJob(String baseURL, String dbName, String username, String password) {
        this(baseURL, dbName, username, password, null);
    }
    
    public PedidosBatchJob(String baseURL, String dbName, String username, String password, String mockPayload) {
        this.baseURL = baseURL;
        this.dbName = dbName;
        this.username = username;
        this.password = password;
        this.mockPayload = mockPayload;
        
        this.batchCtx = BatchIntegrationHelper.createContext('Pedidos Integration', dbName);
        
        Object mockData = BatchIntegrationHelper.parseMockPayload(mockPayload, batchCtx);
        if (mockData instanceof List<Object>) {
            for (Object obj : (List<Object>) mockData) {
                accumulatedOrders.add((Map<String, Object>) obj);
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
            processPedidos(accumulatedOrders, jobId);
            return;
        }
        
        String expandValue = 'Orders($select=DocEntry,DocNum,DocType,DocDate,DocTime,DocDueDate,DocTotal,CardCode,Address,Address2,NumAtCard,DocCurrency,SalesPersonCode,Comments,ShipToCode,U_RUTA,U_RECETA,U_SEI_IDW),Orders/DocumentLines($select=LineNum,ItemCode,Quantity,Price,PriceAfterVAT,BarCode,ShipDate,TaxCode)';
        String filterValue = 'Orders/DocEntry eq Orders/DocumentLines/DocEntry and Orders/UpdateDate gt \'2025-08-01\'';
        String encodedExpand = EncodingUtil.urlEncode(expandValue, 'UTF-8');
        String encodedFilter = EncodingUtil.urlEncode(filterValue, 'UTF-8');
        String resourcePath = '/$crossjoin(Orders,Orders/DocumentLines)?$expand=' + encodedExpand + '&$filter=' + encodedFilter;
        
        List<Map<String, Object>> fetchedData = BatchIntegrationHelper.fetchLiveData(
            this.baseURL,
            this.dbName,
            this.username,
            this.password,
            resourcePath,
            batchCtx
        );
        
        if (!fetchedData.isEmpty()) {
            accumulatedOrders.addAll(fetchedData);
        }
        
        if (!accumulatedOrders.isEmpty()) {
            processPedidos(accumulatedOrders, jobId);
        }
    }
    
    public void finish(Database.BatchableContext bc) {        
        String jobId = bc != null ? String.valueOf(bc.getJobId()) : null;
        
        Map<String, Object> processingData = new Map<String, Object>();
        
        if (processingResult != null) {
            processingData.put('ordersProcessed', processingResult.ordersProcessed);
            processingData.put('ordersUpserted', processingResult.ordersUpserted);
            processingData.put('linesProcessed', processingResult.linesProcessed);
            processingData.put('linesUpserted', processingResult.linesUpserted);
            
            if (processingResult.ordersSkipped > 0) {
                processingData.put('ordersSkipped', processingResult.ordersSkipped);
            }
            if (processingResult.linesSkipped > 0) {
                processingData.put('linesSkipped', processingResult.linesSkipped);
            }
            if (!processingResult.rejectedRawOrders.isEmpty()) {
                processingData.put('rejectedRawOrders', processingResult.rejectedRawOrders);
            }
            if (!processingResult.skippedOrderDetails.isEmpty()) {
                processingData.put('skippedOrders', processingResult.skippedOrderDetails);
            }
            if (!processingResult.skippedLineDetails.isEmpty()) {
                processingData.put('skippedLines', processingResult.skippedLineDetails);
            }
            if (!processingResult.orderErrors.isEmpty()) {
                processingData.put('orderErrors', processingResult.orderErrors);
            }
            if (!processingResult.lineErrors.isEmpty()) {
                processingData.put('lineErrors', processingResult.lineErrors);
            }
        } else {
            processingData.put('ordersProcessed', 0);
            processingData.put('ordersUpserted', 0);
            processingData.put('linesProcessed', 0);
            processingData.put('linesUpserted', 0);
        }
        
        Map<String, Object> summary = BatchIntegrationHelper.buildDiagnosticSummary(batchCtx, processingData);
        
        Boolean hasIssues = BatchIntegrationHelper.hasSignificantIssues(batchCtx, processingData);
        
        if (hasIssues) {
            IntegrationLogger.logError('Pedidos Integration', summary, jobId);
        } else {
            IntegrationLogger.logSuccess('Pedidos Integration', summary, jobId);
        }
    }
    
    private void processPedidos(List<Map<String, Object>> orderNodes, String jobId) {
        try {
            this.processingResult = PedidosController.processOrderList(orderNodes, jobId);
        } catch (Exception ex) {
            batchCtx.rootCauseError = 'Exception in PedidosController: ' + ex.getMessage();
            batchCtx.errorStackTrace = ex.getStackTraceString();
        }
    }
}
