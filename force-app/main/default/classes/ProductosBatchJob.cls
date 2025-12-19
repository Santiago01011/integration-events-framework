/**
 * @description Batch Apex class for synchronizing products from SAP B1 with pagination support.
 * Extends BasePaginatedBatchJob to implement the State-Chaining Batch pattern.
 * Processes one page at a time and automatically chains to the next page until complete.
 */
public class ProductosBatchJob extends BasePaginatedBatchJob {
    
    private static final String INTEGRATION_LABEL = 'Productos Integration';
    private static final String EXPAND_VALUE = 'Manufacturers($select=ManufacturerName),Items($select=ItemCode,ItemName,U_SEI_PA,U_SEI_GEN,U_SEI_ROT,U_Departamento,U_Categoria,U_SubCategoria,Valid,BarCode,U_SEI_FAM,U_SEI_SUBFAM,Mainsupplier,DefaultWarehouse,UpdateDate),ItemGroups($select=GroupName)';
    
    private ProductosController.ProcessResult processingResult;
    
    public ProductosBatchJob(String baseURL, String companyDB, String password, String dbName) {
        this(baseURL, companyDB, null, password, dbName, '2025-08-01', null, null, null);
    }
    
    public ProductosBatchJob(
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
        String filterValue = 'Items/Manufacturer eq Manufacturers/Code and Items/ItemsGroupCode eq ItemGroups/Number and Items/Valid eq \'Y\' and Items/UpdateDate gt \'' + this.lastSyncDateStr + '\'';
        String encodedFilter = EncodingUtil.urlEncode(filterValue, 'UTF-8');
        return '/$crossjoin(Items,Manufacturers,ItemGroups)?$expand=' + encodedExpand + '&$filter=' + encodedFilter;
    }
    
    protected override Object processPageData(List<Map<String, Object>> pageData, String jobId) {
        try {
            this.processingResult = ProductosController.processProductList(pageData);
            return this.processingResult;
        } catch (Exception ex) {
            batchCtx.rootCauseError = 'Exception in ProductosController: ' + ex.getMessage();
            batchCtx.errorStackTrace = ex.getStackTraceString();
            return null;
        }
    }
    
    protected override void updateSummaryFromResult(Object result) {
        if (result instanceof ProductosController.ProcessResult) {
            ProductosController.ProcessResult pageResult = (ProductosController.ProcessResult) result;
            this.summary.totalRecordsProcessed += pageResult.productsProcessed;
            this.summary.totalRecordsUpserted += pageResult.productsUpserted;
            this.summary.totalRecordsSkipped += pageResult.productsSkipped;
            
            for (String error : pageResult.productErrors) {
                this.summary.addError(error);
            }
        }
    }
    
    protected override Map<String, Object> buildProcessingData() {
        Map<String, Object> processingData = new Map<String, Object>();
        
        processingData.put('productsProcessed', this.summary.totalRecordsProcessed);
        processingData.put('productsUpserted', this.summary.totalRecordsUpserted);
        
        if (this.summary.totalRecordsSkipped > 0) {
            processingData.put('productsSkipped', this.summary.totalRecordsSkipped);
        }
        
        if (this.processingResult != null) {
            if (!this.processingResult.skippedProductDetails.isEmpty()) {
                processingData.put('skippedProductDetails', this.processingResult.skippedProductDetails);
            }
            if (!this.processingResult.productErrors.isEmpty()) {
                processingData.put('productErrors', this.processingResult.productErrors);
            }
        }
        
        return processingData;
    }
    
    protected override BasePaginatedBatchJob createNextInstance() {
        return new ProductosBatchJob(
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
