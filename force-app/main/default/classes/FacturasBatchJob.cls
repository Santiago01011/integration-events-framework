/**
 * @description Batch Apex class for synchronizing Invoices and Invoice Lines from SAP B1 with pagination support.
 * Extends BasePaginatedBatchJob to implement the State-Chaining Batch pattern.
 * Processes one page at a time and automatically chains to the next page until complete.
 */
public class FacturasBatchJob extends BasePaginatedBatchJob {
    
    private static final String INTEGRATION_LABEL = 'Facturas Integration';
    private static final String EXPAND_VALUE = 'Invoices($select=DocEntry,DocNum,FolioNumber,DocDate,DocDueDate,DocCurrency,U_SEI_FEBOSID,DocType,Address,Address2,ShipToCode,NumAtCard,DocTotal,SalesPersonCode,Comments,U_Receta,U_SEI_IDW,CardCode),Invoices/DocumentLines($select=LineNum,ItemCode,ItemDescription,Quantity,ShipDate,Price,PriceAfterVAT,WarehouseCode,BarCode,TaxCode)';
    
    private FacturasController.ProcessResult processingResult;
    
    public FacturasBatchJob(String baseURL, String companyDB, String password, String dbName) {
        this(baseURL, companyDB, null, password, dbName, '2025-08-01', null, null, null);
    }
    
    public FacturasBatchJob(
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
        String filterValue = 'Invoices/DocEntry eq Invoices/DocumentLines/DocEntry and Invoices/UpdateDate gt \'' + this.lastSyncDateStr + '\'';
        String encodedFilter = EncodingUtil.urlEncode(filterValue, 'UTF-8');
        return '/$crossjoin(Invoices,Invoices/DocumentLines)?$expand=' + encodedExpand + '&$filter=' + encodedFilter;
    }
    
    protected override Object processPageData(List<Map<String, Object>> pageData, String jobId) {
        try {
            this.processingResult = FacturasController.processInvoiceList(pageData);
            return this.processingResult;
        } catch (Exception ex) {
            batchCtx.rootCauseError = 'Exception in FacturasController: ' + ex.getMessage();
            batchCtx.errorStackTrace = ex.getStackTraceString();
            return null;
        }
    }
    
    protected override void updateSummaryFromResult(Object result) {
        if (result instanceof FacturasController.ProcessResult) {
            FacturasController.ProcessResult pageResult = (FacturasController.ProcessResult) result;
            this.summary.totalRecordsProcessed += pageResult.invoicesProcessed;
            this.summary.totalRecordsUpserted += pageResult.invoicesUpserted;
            this.summary.totalRecordsSkipped += pageResult.invoicesSkipped;
            
            this.summary.totalLinesProcessed += pageResult.linesProcessed;
            this.summary.totalLinesUpserted += pageResult.linesUpserted;
            this.summary.totalLinesSkipped += pageResult.linesSkipped;
            
            for (FacturasController.InvoiceError error : pageResult.invoiceErrors) {
                this.summary.addError('Invoice ' + error.docEntry + ': ' + error.message);
            }
            for (FacturasController.LineError error : pageResult.lineErrors) {
                this.summary.addError('Line ' + error.docEntryLine + ': ' + error.message);
            }
        }
    }
    
    protected override Map<String, Object> buildProcessingData() {
        Map<String, Object> processingData = new Map<String, Object>();
        
        processingData.put('invoicesProcessed', this.summary.totalRecordsProcessed);
        processingData.put('invoicesUpserted', this.summary.totalRecordsUpserted);
        processingData.put('linesProcessed', this.summary.totalLinesProcessed);
        processingData.put('linesUpserted', this.summary.totalLinesUpserted);
        
        if (this.summary.totalRecordsSkipped > 0) {
            processingData.put('invoicesSkipped', this.summary.totalRecordsSkipped);
        }
        if (this.summary.totalLinesSkipped > 0) {
            processingData.put('linesSkipped', this.summary.totalLinesSkipped);
        }
        
        if (this.processingResult != null) {
            if (!this.processingResult.skippedInvoiceDetails.isEmpty()) {
                processingData.put('skippedInvoices', this.processingResult.skippedInvoiceDetails);
            }
            if (!this.processingResult.skippedLineDetails.isEmpty()) {
                processingData.put('skippedLines', this.processingResult.skippedLineDetails);
            }
            if (!this.processingResult.invoiceErrors.isEmpty()) {
                processingData.put('invoiceErrors', this.processingResult.invoiceErrors);
            }
            if (!this.processingResult.lineErrors.isEmpty()) {
                processingData.put('lineErrors', this.processingResult.lineErrors);
            }
        }
        
        return processingData;
    }
    
    protected override BasePaginatedBatchJob createNextInstance() {
        return new FacturasBatchJob(
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
