/**
 * @description Batch Apex class for synchronizing Orders and OrderItems from SAP B1 with pagination support.
 * Extends BasePaginatedBatchJob to implement the State-Chaining Batch pattern.
 * Processes one page at a time and automatically chains to the next page until complete.
 */
public without sharing class PedidosBatchJob extends BasePaginatedBatchJob {
    
    private static final String INTEGRATION_LABEL = 'Pedidos Integration';
    private static final String EXPAND_VALUE = 'Orders($select=DocEntry,DocNum,DocType,DocDate,DocDueDate,CardCode,CardName,Address,NumAtCard,DocTotal,DocCurrency,SalesPersonCode,DocTime,Comments,ShipToCode,FederalTaxID,DocumentStatus,Address2,U_Receta,U_SEI_IDW),Orders/DocumentLines($select=LineNum,ItemCode,ItemDescription,Quantity,ShipDate,Price,PriceAfterVAT,WarehouseCode,BarCode,TaxCode)';
    
    private PedidosController.ProcessResult processingResult;
    
    public PedidosBatchJob(String baseURL, String companyDB, String password, String dbName) {
        this(baseURL, companyDB, null, password, dbName, '2025-08-01', null, null, null);
    }
    
    public PedidosBatchJob(
        String baseURL,
        String companyDB,
        String username,
        String password,
        String dbName,
        String lastSyncDateStr,
        String nextLink,
        BatchSummary summary,
        String mockPayload
    ) {
        super(baseURL, companyDB, username, password, lastSyncDateStr, nextLink, summary, mockPayload);
        this.processingResult = null;
    }
    
    protected override String getIntegrationLabel() {
        return INTEGRATION_LABEL;
    }
    
    protected override String getInitialResourcePath() {
        String encodedExpand = EncodingUtil.urlEncode(EXPAND_VALUE, 'UTF-8');
        String filterValue = 'Orders/DocEntry eq Orders/DocumentLines/DocEntry and Orders/UpdateDate gt \'' + this.lastSyncDateStr + '\'';
        String encodedFilter = EncodingUtil.urlEncode(filterValue, 'UTF-8');
        return '/$crossjoin(Orders,Orders/DocumentLines)?$expand=' + encodedExpand + '&$filter=' + encodedFilter;
    }
    
    protected override Object processPageData(List<Map<String, Object>> pageData, String jobId) {
        try {
            this.processingResult = PedidosController.processOrderList(pageData);
            return this.processingResult;
        } catch (Exception ex) {
            batchCtx.rootCauseError = 'Exception in PedidosController: ' + ex.getMessage();
            batchCtx.errorStackTrace = ex.getStackTraceString();
            return null;
        }
    }
    
    protected override void updateSummaryFromResult(Object result) {
        if (result instanceof PedidosController.ProcessResult) {
            PedidosController.ProcessResult pageResult = (PedidosController.ProcessResult) result;
            this.summary.totalRecordsProcessed += pageResult.ordersProcessed;
            this.summary.totalRecordsUpserted += pageResult.ordersUpserted;
            this.summary.totalRecordsSkipped += pageResult.ordersSkipped;
            
            this.summary.totalLinesProcessed += pageResult.linesProcessed;
            this.summary.totalLinesUpserted += pageResult.linesUpserted;
            this.summary.totalLinesSkipped += pageResult.linesSkipped;
            
            for (PedidosController.OrderError error : pageResult.orderErrors) {
                this.summary.addError('Order ' + error.docEntry + ': ' + error.message);
            }
            for (PedidosController.LineError error : pageResult.lineErrors) {
                this.summary.addError('Line ' + error.docEntryLine + ': ' + error.message);
            }
        }
    }
    
    protected override Map<String, Object> buildProcessingData() {
        Map<String, Object> processingData = new Map<String, Object>();
        
        processingData.put('ordersProcessed', this.summary.totalRecordsProcessed);
        processingData.put('ordersUpserted', this.summary.totalRecordsUpserted);
        processingData.put('linesProcessed', this.summary.totalLinesProcessed);
        processingData.put('linesUpserted', this.summary.totalLinesUpserted);
        
        if (this.summary.totalRecordsSkipped > 0) {
            processingData.put('ordersSkipped', this.summary.totalRecordsSkipped);
        }
        if (this.summary.totalLinesSkipped > 0) {
            processingData.put('linesSkipped', this.summary.totalLinesSkipped);
        }
        
        if (this.processingResult != null) {
            if (!this.processingResult.rejectedRawOrders.isEmpty()) {
                processingData.put('rejectedRawOrders', this.processingResult.rejectedRawOrders);
            }
            if (!this.processingResult.skippedOrderDetails.isEmpty()) {
                processingData.put('skippedOrders', this.processingResult.skippedOrderDetails);
            }
            if (!this.processingResult.skippedLineDetails.isEmpty()) {
                processingData.put('skippedLines', this.processingResult.skippedLineDetails);
            }
            if (!this.processingResult.orderErrors.isEmpty()) {
                processingData.put('orderErrors', this.processingResult.orderErrors);
            }
            if (!this.processingResult.lineErrors.isEmpty()) {
                processingData.put('lineErrors', this.processingResult.lineErrors);
            }
        }
        
        return processingData;
    }
    
    protected override BasePaginatedBatchJob createNextInstance() {
        return new PedidosBatchJob(
            this.baseURL,
            this.companyDB,
            this.username,
            this.password,
            this.companyDB,
            this.lastSyncDateStr,
            this.nextLinkForFinish,
            this.summary,
            null
        );
    }
}
