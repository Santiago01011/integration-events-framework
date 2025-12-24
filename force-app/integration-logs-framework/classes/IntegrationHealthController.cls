/**
 * @description Controller for the Integration Health Dashboard components.
 * Provides methods to query, update, and aggregate integration log data.
 */
public with sharing class IntegrationHealthController {

    private static final Integer DEFAULT_PAGE_SIZE = 20;
    private static final String ILLEGALARGUMENT = 'Illegal argument';   
    
    @AuraEnabled(cacheable=false)
    public static IntegrationLogPage getRecentLogs(
        Integer pageSize,
        String search,
        String fromOccurredAt,
        String toOccurredAt,
        Datetime lastOccurredAt,
        Id lastId,
        String correlationId,
        String observationType,
        String integrationCode
    ) {
        if (pageSize == null || pageSize <= 0 || pageSize > 200) {
            pageSize = DEFAULT_PAGE_SIZE;
        }

        List<Integration_Log__c> records = queryLogs(pageSize, search, fromOccurredAt, toOccurredAt, lastOccurredAt, lastId, correlationId, observationType, integrationCode);
        
        IntegrationLogPage page = new IntegrationLogPage();
        page.records = records;
        page.pageSize = pageSize;

        if (!records.isEmpty()) {
            Integration_Log__c lastRecord = records[records.size() - 1];
            page.nextKey = new KeysetToken(lastRecord.OccurredAt__c, lastRecord.Id);
        }
        
        page.hasMore = records.size() >= pageSize;
        
        return page;
    }

    @AuraEnabled(cacheable=false)
    public static LogDetailWrapper getLogDetail(Id logId) {
        if (logId == null) {
            throw new AuraHandledException(ILLEGALARGUMENT);
        }

        List<Integration_Log__c> records = [
            SELECT Id, Context__c, Normalized_Context__c, ObservationType__c, IntegrationCode__c, CorrelationId__c, ParentEventId__c, OccurredAt__c
            FROM Integration_Log__c
            WHERE Id = :logId
            WITH USER_MODE
            LIMIT 1
        ];

        if (records.isEmpty()) {
            throw new AuraHandledException('Log record not found.');
        }

        Integration_Log__c log = records[0];
        LogDetailWrapper wrapper = new LogDetailWrapper();
        wrapper.record = log;
        
        // Fetch severity from metadata
        List<idhIntegration_Evaluation_Rule__mdt> rules = [
            SELECT Severity__c 
            FROM idhIntegration_Evaluation_Rule__mdt 
            WHERE ObservationType__c = :log.ObservationType__c
            WITH USER_MODE
            LIMIT 1
        ];
        
        wrapper.severity = !rules.isEmpty() ? rules[0].Severity__c : 'INFO';

        return wrapper;
    }

    private static List<Integration_Log__c> queryLogs(
        Integer pageSize,
        String search,
        String fromOccurredAtStr,
        String toOccurredAtStr,
        Datetime lastOccurredAt,
        Id lastId,
        String correlationId,
        String observationType,
        String integrationCode
    ) {
        Datetime fromOccurredAt;
        Datetime toOccurredAt;
        
        if (String.isNotBlank(fromOccurredAtStr)) {
            fromOccurredAt = (Datetime) JSON.deserialize('"' + fromOccurredAtStr + '"', Datetime.class);
        }
        
        if (String.isNotBlank(toOccurredAtStr)) {
            toOccurredAt = (Datetime) JSON.deserialize('"' + toOccurredAtStr + '"', Datetime.class);
        }
        
        List<String> fieldsToQuery = new List<String>{
            'Id', 'OccurredAt__c', 'Normalized_Context__c',
            'ObservationType__c', 'IntegrationCode__c', 'CorrelationId__c', 'ParentEventId__c'
        };

        String accessibleFields = getAccessibleFieldsAsCsv(fieldsToQuery);
        String soql = 'SELECT ' + accessibleFields + ' FROM Integration_Log__c';
        
        List<String> conditions = new List<String>();
        Map<String, Object> bindMap = new Map<String, Object>();
        
        if (String.isNotBlank(search)) {
            String searchTerm = '%' + search + '%';
            conditions.add('(ObservationType__c LIKE :searchTerm OR IntegrationCode__c LIKE :searchTerm OR CorrelationId__c LIKE :searchTerm OR Normalized_Context__c LIKE :searchTerm)');
            bindMap.put('searchTerm', searchTerm);
        }

        if (String.isNotBlank(correlationId)) {
            String corrTerm = '%' + correlationId + '%';
            conditions.add('CorrelationId__c LIKE :corrTerm');
            bindMap.put('corrTerm', corrTerm);
        }

        if (String.isNotBlank(observationType)) {
            conditions.add('ObservationType__c = :observationType');
            bindMap.put('observationType', observationType);
        }

        if (String.isNotBlank(integrationCode)) {
            String integTerm = '%' + integrationCode + '%';
            conditions.add('IntegrationCode__c LIKE :integTerm');
            bindMap.put('integTerm', integTerm);
        }
        
        if (fromOccurredAt != null) {
            conditions.add('OccurredAt__c >= :fromOccurredAt');
            bindMap.put('fromOccurredAt', fromOccurredAt);
        }
        
        if (toOccurredAt != null) {
            conditions.add('OccurredAt__c <= :toOccurredAt');
            bindMap.put('toOccurredAt', toOccurredAt);
        }
        
        if (lastOccurredAt != null && lastId != null) {
            conditions.add('(OccurredAt__c < :lastOccurredAt OR (OccurredAt__c = :lastOccurredAt AND Id < :lastId))');
            bindMap.put('lastOccurredAt', lastOccurredAt);
            bindMap.put('lastId', lastId);
        }
        
        if (!conditions.isEmpty()) {
            soql += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        soql += ' ORDER BY OccurredAt__c DESC, Id DESC LIMIT :pageSize';
        bindMap.put('pageSize', pageSize);
        
        return Database.queryWithBinds(soql, bindMap, AccessLevel.USER_MODE);
    }
    
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

    public class LogDetailWrapper {
        @AuraEnabled public Integration_Log__c record { get; set; }
        @AuraEnabled public String severity { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<IntegrationSummary> getIntegrationSummaries() {
        Map<String, IntegrationSummary> summaryMap = new Map<String, IntegrationSummary>();

        Map<String, String> typeToSeverity = new Map<String, String>();
        for (idhIntegration_Evaluation_Rule__mdt rule : [
            SELECT ObservationType__c, Severity__c 
            FROM idhIntegration_Evaluation_Rule__mdt 
            WITH USER_MODE
        ]) {
            typeToSeverity.put(rule.ObservationType__c.toUpperCase(), rule.Severity__c);
        }

        for (AggregateResult ar : [
            SELECT Normalized_Context__c norm, IntegrationCode__c code, ObservationType__c type, COUNT(Id) total, MAX(OccurredAt__c) lastOccurred
            FROM Integration_Log__c
            WITH USER_MODE
            GROUP BY Normalized_Context__c, IntegrationCode__c, ObservationType__c
        ]) {
            String norm = (String) ar.get('norm');
            String code = (String) ar.get('code');
            String type = (String) ar.get('type');
            Integer count = (Integer) ar.get('total');
            Datetime lastOccurred = (Datetime) ar.get('lastOccurred');

            String key = String.isNotBlank(norm) ? norm : code;
            if (String.isBlank(key)) {
                continue;
            }

            if (!summaryMap.containsKey(key)) {
                IntegrationSummary summary = new IntegrationSummary();
                summary.integrationCode = key;
                summary.displayName = key;
                summary.totalEvents = 0;
                summary.successCount = 0;
                summary.errorCount = 0;
                summary.normalizedContext = norm;
                summaryMap.put(key, summary);
            }

            IntegrationSummary summary = summaryMap.get(key);
            summary.totalEvents += count;
            if (summary.lastOccurredAt == null || lastOccurred > summary.lastOccurredAt) {
                summary.lastOccurredAt = lastOccurred;
            }

            String severity = type != null ? typeToSeverity.get(type.toUpperCase()) : null;
            
            if (severity == 'ERROR' || severity == 'FATAL' || severity == 'WARN') {
                summary.errorCount += count;
            } else {
                summary.successCount += count;
            }
        }

        return summaryMap.values();
    }

    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        FilterOptions options = new FilterOptions();
        
        // Get unique Observation Types from Logs
        for (AggregateResult ar : [SELECT ObservationType__c type FROM Integration_Log__c WHERE ObservationType__c != null GROUP BY ObservationType__c]) {
            options.observationTypes.add((String) ar.get('type'));
        }
        options.observationTypes.sort();

        // Get unique Integration Codes from Logs
        for (AggregateResult ar : [SELECT IntegrationCode__c code FROM Integration_Log__c WHERE IntegrationCode__c != null GROUP BY IntegrationCode__c]) {
            options.integrationCodes.add((String) ar.get('code'));
        }
        options.integrationCodes.sort();

        return options;
    }

    public class FilterOptions {
        @AuraEnabled public List<String> observationTypes = new List<String>();
        @AuraEnabled public List<String> integrationCodes = new List<String>();
    }

    @AuraEnabled(cacheable=true)
    public static String getEventChannel() {
        String eventName = IntegrationEvent__e.SObjectType.getDescribe().getName();
        return '/event/' + eventName;
    }

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
    
    public class KeysetToken {
        @AuraEnabled
        public Datetime lastOccurredAt { get; set; }
        
        @AuraEnabled
        public Id lastId { get; set; }
        
        public KeysetToken(Datetime occurredAt, Id recordId) {
            this.lastOccurredAt = occurredAt;
            this.lastId = recordId;
        }
    }
    
    public class IntegrationSummary {
        @AuraEnabled public String integrationCode { get; set; }
        @AuraEnabled public String normalizedContext { get; set; }
        @AuraEnabled public String displayName { get; set; }
        @AuraEnabled public Integer totalEvents { get; set; }
        @AuraEnabled public Integer successCount { get; set; }
        @AuraEnabled public Integer errorCount { get; set; }
        @AuraEnabled public Datetime lastOccurredAt { get; set; }
    }
}

