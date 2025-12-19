/**
 * @description Batch Apex class for synchronizing Addresses from SAP B1 with pagination support.
 * Extends BasePaginatedBatchJob to implement the State-Chaining Batch pattern.
 * Processes one page at a time and automatically chains to the next page until complete.
 */
public class DireccionesBatchJob extends BasePaginatedBatchJob {
    
    private static final String INTEGRATION_LABEL = 'Direcciones Integration';
    private static final String EXPAND_VALUE = 'BusinessPartners($select=CardCode,CardName),BusinessPartners/BPAddresses($select=BPCode,AddressName,Street,City,County,State,U_Ruta,AddressType)';
    
    private DireccionesController.ProcessResult processingResult;
    
    public DireccionesBatchJob(String baseURL, String companyDB, String password, String dbName) {
        this(baseURL, companyDB, null, password, dbName, '2025-08-01', null, null, null);
    }
    
    public DireccionesBatchJob(
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
        String filterValue = 'BusinessPartners/CardCode eq BusinessPartners/BPAddresses/BPCode';
        String encodedFilter = EncodingUtil.urlEncode(filterValue, 'UTF-8');
        return '/$crossjoin(BusinessPartners,BusinessPartners/BPAddresses)?$expand=' + encodedExpand + '&$filter=' + encodedFilter;
    }
    
    protected override Object processPageData(List<Map<String, Object>> pageData, String jobId) {
        try {
            this.processingResult = DireccionesController.processAddressList(pageData);
            return this.processingResult;
        } catch (Exception ex) {
            batchCtx.rootCauseError = 'Exception in DireccionesController: ' + ex.getMessage();
            batchCtx.errorStackTrace = ex.getStackTraceString();
            return null;
        }
    }
    
    protected override void updateSummaryFromResult(Object result) {
        if (result instanceof DireccionesController.ProcessResult) {
            DireccionesController.ProcessResult pageResult = (DireccionesController.ProcessResult) result;
            this.summary.totalRecordsProcessed += pageResult.addressesProcessed;
            this.summary.totalRecordsUpserted += pageResult.addressesUpserted;
            this.summary.totalRecordsSkipped += pageResult.addressesSkipped;
            
            for (DireccionesController.AddressError error : pageResult.addressErrors) {
                this.summary.addError('Address ' + error.addressId + ': ' + error.message);
            }
        }
    }
    
    protected override Map<String, Object> buildProcessingData() {
        Map<String, Object> processingData = new Map<String, Object>();
        
        processingData.put('addressesProcessed', this.summary.totalRecordsProcessed);
        processingData.put('addressesUpserted', this.summary.totalRecordsUpserted);
        
        if (this.summary.totalRecordsSkipped > 0) {
            processingData.put('addressesSkipped', this.summary.totalRecordsSkipped);
        }
        
        if (this.processingResult != null) {
            if (!this.processingResult.skippedAddressDetails.isEmpty()) {
                processingData.put('skippedAddressDetails', this.processingResult.skippedAddressDetails);
            }
            if (!this.processingResult.addressErrors.isEmpty()) {
                processingData.put('addressErrors', this.processingResult.addressErrors);
            }
        }
        
        return processingData;
    }
    
    protected override BasePaginatedBatchJob createNextInstance() {
        return new DireccionesBatchJob(
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

