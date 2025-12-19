/**
 * @description Controller for the Integration Health Dashboard components.
 * Provides methods to query, update, and aggregate integration log data.
 */
public with sharing class IntegrationHealthController {
    
    private static final Integer DEFAULT_PAGE_SIZE = 20;
    private static final String ILLEGALARGUMENT = 'Illegal argument';   
    
    /**
     * @description Retrieves a paginated list of recent integration logs based on specified filters.
     * @param pageSize The number of records to return per page.
     * @param statusFilter Filters logs by 'Processed' or 'Error' status.
     * @param search A search term to filter logs by Context, PayloadId, or JobId.
     * @param fromDate The start date for the date range filter.
     * @param toDate The end date for the date range filter.
     * @param lastCreatedDate The CreatedDate of the last record from the previous page (for keyset pagination).
     * @param lastId The Id of the last record from the previous page (for keyset pagination).
     * @return An `IntegrationLogPage` containing the records and pagination information.
     */
    @AuraEnabled(cacheable=false)
    public static IntegrationLogPage getRecentLogs(
        Integer pageSize,
        String statusFilter,
        String search,
        Datetime fromDate,
        Datetime toDate,
        Datetime lastCreatedDate,
        Id lastId
        , String correlationId
    ) {
        if (pageSize == null || pageSize <= 0 || pageSize > 200) {
            pageSize = DEFAULT_PAGE_SIZE;
        }
        
        List<Integration_Log__c> records = queryLogs(pageSize, statusFilter, search, fromDate, toDate, lastCreatedDate, lastId);
        
        IntegrationLogPage page = new IntegrationLogPage();
        page.records = records;
        page.pageSize = pageSize;

        if (!records.isEmpty()) {
            Integration_Log__c lastRecord = records[records.size() - 1];
            page.nextKey = new KeysetToken(lastRecord.CreatedDate, lastRecord.Id);
        }
        
        page.hasMore = records.size() >= pageSize;
        
        return page;
    }
    
    /**
     * @description Constructs and executes the SOQL query to fetch integration logs.
     * @param pageSize The number of records to query.
     * @param statusFilter The status to filter by ('Processed' or 'Error').
     * @param search The search term.
     * @param fromDate The start date of the filter range.
     * @param toDate The end date of the filter range.
     * @param lastCreatedDate The last CreatedDate for keyset pagination.
     * @param lastId The last Id for keyset pagination.
     * @return A list of `Integration_Log__c` records.
     */
    private static List<Integration_Log__c> queryLogs(
        Integer pageSize,
        String statusFilter,
        String search,
        Datetime fromDate,
        Datetime toDate,
        Datetime lastCreatedDate,
        Id lastId
    ) {
        List<String> fieldsToQuery = new List<String>{
            'Id', 'Context__c', 'PayloadId__c', 
            'JobId__c', 'Processed__c', 'Source__c', 'CreatedDate'
        };

        String accessibleFields = getAccessibleFieldsAsCsv(fieldsToQuery);
        String soql = 'SELECT ' + accessibleFields + ' FROM Integration_Log__c';
        
        List<String> conditions = new List<String>();
        Map<String, Object> bindMap = new Map<String, Object>();
        
        if (String.isNotBlank(statusFilter)) {
            Boolean isProcessed = statusFilter.equalsIgnoreCase('Processed');
            conditions.add('Processed__c = :isProcessed');
            bindMap.put('isProcessed', isProcessed);
        }
        
        if (String.isNotBlank(search)) {
            String searchTerm = '%' + search + '%';
            conditions.add('(Context__c LIKE :searchTerm OR PayloadId__c LIKE :searchTerm OR JobId__c LIKE :searchTerm)');
            bindMap.put('searchTerm', searchTerm);
        }
        
        if (fromDate != null) {
            conditions.add('CreatedDate >= :fromDate');
            bindMap.put('fromDate', fromDate);
        }
        
        if (toDate != null) {
            conditions.add('CreatedDate <= :toDate');
            bindMap.put('toDate', toDate);
        }
        
        if (lastCreatedDate != null && lastId != null) {
            conditions.add('(CreatedDate < :lastCreatedDate OR (CreatedDate = :lastCreatedDate AND Id < :lastId))');
            bindMap.put('lastCreatedDate', lastCreatedDate);
            bindMap.put('lastId', lastId);
        }
        
        if (!conditions.isEmpty()) {
            soql += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        soql += ' ORDER BY CreatedDate DESC, Id DESC LIMIT :pageSize';
        bindMap.put('pageSize', pageSize);
        
        return Database.queryWithBinds(soql, bindMap, AccessLevel.USER_MODE);
    }
    
    /**
     * @description Checks FLS for a list of fields on Integration_Log__c and returns an accessible field list as a CSV string.
     * @param fieldsToCheck A list of field API names.
     * @return A comma-separated string of accessible fields.
     */
    private static String getAccessibleFieldsAsCsv(List<String> fieldsToCheck) {
        List<String> accessibleFields = new List<String>();
        DescribeSObjectResult sObjectDescribe = Integration_Log__c.sObjectType.getDescribe();
        Map<String, SObjectField> fieldMap = sObjectDescribe.fields.getMap();
        for (String fieldName : fieldsToCheck) {
            if (fieldMap.containsKey(fieldName)) {
                SObjectField fieldToken = fieldMap.get(fieldName);
                DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
                if (fieldDescribe.isAccessible()) {
                    accessibleFields.add(fieldName);
                }
            }
        }        
        if (accessibleFields.isEmpty()) {
            throw new AuraHandledException('The current user does not have access to any fields on the Integration_Log__c object.');
        }
        return String.join(accessibleFields, ', ');
    }
    
    /**
     * @description Retrieves a single integration log with all fields including heavy fields like StackTrace.
     * This method is called on demand when the detail drawer is opened to avoid loading heavy data upfront.
     * @param logId The Id of the integration log to retrieve.
     * @return The complete Integration_Log__c record with all fields.
     */
    @AuraEnabled(cacheable=false)
    public static Integration_Log__c getLogDetail(Id logId) {
        if (logId == null) {
            throw new AuraHandledException(ILLEGALARGUMENT);
        }

        List<Integration_Log__c> records = [
            SELECT Id, Context__c, Message__c, StackTrace__c, PayloadId__c, 
                   JobId__c, Processed__c, Source__c, CreatedDate
            FROM Integration_Log__c
            WHERE Id = :logId
            WITH USER_MODE
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new AuraHandledException('Log record not found.');
        }

        return records[0];
    }

    /**
     * @description Updates the 'Processed' status of a list of integration logs.
     * @param logIds A list of `Integration_Log__c` record Ids to update.
     * @param processed The new boolean value for the `Processed__c` field.
     */
    @AuraEnabled
    public static void setLogProcessed(List<Id> logIds, Boolean processed) {
        if (logIds == null || logIds.isEmpty()) {
            throw new AuraHandledException(ILLEGALARGUMENT);
        }
        
        List<Integration_Log__c> logsToUpdate = new List<Integration_Log__c>();
        for (Id logId : logIds) {
            logsToUpdate.add(new Integration_Log__c(
                Id = logId,
                Processed__c = processed
            ));
        }
        
        Database.update(logsToUpdate, AccessLevel.USER_MODE);
    }
    
    @AuraEnabled(cacheable=true)
    public static AggregateData getAggregates() {
        AggregateData agg = new AggregateData();

        AggregateResult[] errorResults = [
            SELECT COUNT(Id) cnt FROM Integration_Log__c 
            WHERE Processed__c = false
            WITH USER_MODE
        ];
        agg.errorCount = (Integer) errorResults[0].get('cnt');

        AggregateResult[] processedResults = [
            SELECT COUNT(Id) cnt FROM Integration_Log__c 
            WHERE Processed__c = true
            WITH USER_MODE
        ];
        agg.processedCount = (Integer) processedResults[0].get('cnt');

        agg.totalCount = agg.errorCount + agg.processedCount;

        return agg;
    }
    
    /**
     * @description Retrieves and calculates integration summary statistics, grouped by normalized context.
     * @return A list of IntegrationSummary objects.
     */
    @AuraEnabled(cacheable=true)
    public static List<IntegrationSummary> getIntegrationSummaries() {
        Map<String, IntegrationSummary> summaryMap = new Map<String, IntegrationSummary>();

        for (AggregateResult ar : [
            SELECT Normalized_Context__c, COUNT(Id) total, MAX(CreatedDate) lastRun
            FROM Integration_Log__c
            WHERE Normalized_Context__c != null
            WITH USER_MODE
            GROUP BY Normalized_Context__c
        ]) {
            String context = (String) ar.get('Normalized_Context__c');
            
            if (summaryMap.containsKey(context)) {
                IntegrationSummary summary = summaryMap.get(context);
                summary.totalJobs += (Integer) ar.get('total');
                Datetime currentLastRun = (Datetime) ar.get('lastRun');
                if (currentLastRun > summary.lastRunDate) {
                    summary.lastRunDate = currentLastRun;
                }
            } else {
                IntegrationSummary summary = new IntegrationSummary();
                summary.integrationName = context;
                summary.totalJobs = (Integer) ar.get('total');
                summary.lastRunDate = (Datetime) ar.get('lastRun');
                summaryMap.put(context, summary);
            }
        }

        for (AggregateResult ar : [
            SELECT Normalized_Context__c, COUNT(Id) errorCount, MAX(CreatedDate) lastError
            FROM Integration_Log__c
            WHERE Processed__c = false AND Normalized_Context__c != null
            WITH USER_MODE
            GROUP BY Normalized_Context__c
        ]) {
            String context = (String) ar.get('Normalized_Context__c');
            
            if (summaryMap.containsKey(context)) {
                IntegrationSummary summary = summaryMap.get(context);
                summary.errorCount = (summary.errorCount == null ? 0 : summary.errorCount) + (Integer) ar.get('errorCount');
                Datetime currentLastError = (Datetime) ar.get('lastError');
                if (summary.lastErrorDate == null || currentLastError > summary.lastErrorDate) {
                    summary.lastErrorDate = currentLastError;
                }
            }
        }

        for (IntegrationSummary summary : summaryMap.values()) {
            summary.errorCount = summary.errorCount == null ? 0 : summary.errorCount;
            summary.successCount = summary.totalJobs - summary.errorCount;

            if (summary.totalJobs > 0) {
                summary.successPercentage = ((Decimal)summary.successCount / summary.totalJobs * 100).setScale(0);
                summary.errorPercentage = ((Decimal)summary.errorCount / summary.totalJobs * 100).setScale(0);
            } else {
                summary.successPercentage = 0;
                summary.errorPercentage = 0;
            }
        }

        return summaryMap.values();
    }

    /**
     * @description Wrapper class for a page of integration log records.
     */
    public class IntegrationLogPage {
        @AuraEnabled
        public List<Integration_Log__c> records { get; set; }
        
        @AuraEnabled
        public Integer pageSize { get; set; }
        
        @AuraEnabled
        public KeysetToken nextKey { get; set; }
        
        @AuraEnabled
        public Boolean hasMore { get; set; }
    }
    
    /**
     * @description Token used for keyset pagination.
     */
    public class KeysetToken {
        @AuraEnabled
        public Datetime lastCreatedDate { get; set; }
        
        @AuraEnabled
        public Id lastId { get; set; }
        
        public KeysetToken(Datetime createdDate, Id recordId) {
            this.lastCreatedDate = createdDate;
            this.lastId = recordId;
        }
    }
    
    /**
     * @description Wrapper class for aggregate log data.
     */
    public class AggregateData {
        @AuraEnabled
        public Integer errorCount { get; private set; }
        
        @AuraEnabled
        public Integer processedCount { get; private set; }
        
        @AuraEnabled
        public Integer totalCount { get; private set; }
    }

    /**
     * @description Wrapper class to hold summary statistics for an integration or overall system.
     */
    public class IntegrationSummary {
        @AuraEnabled public String integrationName { get; set; }
        @AuraEnabled public Integer totalJobs { get; private set; }
        @AuraEnabled public Integer successCount { get; private set; }
        @AuraEnabled public Integer errorCount { get; private set; }
        @AuraEnabled public Integer processedCount { get; private set; }
        @AuraEnabled public Decimal successPercentage { get; private set; }
        @AuraEnabled public Decimal errorPercentage { get; private set; }
        @AuraEnabled public Datetime lastRunDate { get; private set; }
        @AuraEnabled public Datetime lastErrorDate { get; private set; }
    }
}

