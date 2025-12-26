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
            Datetime lastOccurred = fieldExists('OccurredAt__c') ? lastRecord.OccurredAt__c : null;
            page.nextKey = new KeysetToken(lastOccurred, lastRecord.Id);
        }
        
        page.hasMore = records.size() >= pageSize;
        
        return page;
    }

    @AuraEnabled(cacheable=false)
    public static LogDetailWrapper getLogDetail(Id logId) {
        if (logId == null) {
            throw new AuraHandledException(ILLEGALARGUMENT);
        }

        List<String> detailFields = new List<String>{'Id', 'ObservationType__c', 'IntegrationCode__c', 'CorrelationId__c', 'ParentEventId__c'};
        if (fieldExists('Context__c')) {
            detailFields.add('Context__c');
        }
        if (fieldExists('Normalized_Context__c')) {
            detailFields.add('Normalized_Context__c');
        }
        if (fieldExists('OccurredAt__c')) {
            detailFields.add('OccurredAt__c');
        }

        String detailSelect = 'SELECT ' + String.join(detailFields, ', ') + ' FROM Integration_Log__c WHERE Id = :logId';
        List<Integration_Log__c> records = Database.query(detailSelect + ' WITH SECURITY_ENFORCED LIMIT 1');

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
        
        List<String> fieldsToQuery = new List<String>{'Id', 'ObservationType__c', 'IntegrationCode__c', 'CorrelationId__c', 'ParentEventId__c'};
        if (fieldExists('OccurredAt__c')) {
            fieldsToQuery.add('OccurredAt__c');
        }
        if (fieldExists('Normalized_Context__c')) {
            fieldsToQuery.add('Normalized_Context__c');
        }

        String accessibleFields = getAccessibleFieldsAsCsv(fieldsToQuery);
        String soql = 'SELECT ' + accessibleFields + ' FROM Integration_Log__c';
        
        List<String> conditions = new List<String>();
        Map<String, Object> bindMap = new Map<String, Object>();
        
        if (String.isNotBlank(search)) {
            String searchTerm = '%' + search + '%';
            List<String> searchClauses = new List<String>{
                'ObservationType__c LIKE :searchTerm',
                'IntegrationCode__c LIKE :searchTerm',
                'CorrelationId__c LIKE :searchTerm'
            };
            if (fieldExists('Normalized_Context__c')) {
                searchClauses.add('Normalized_Context__c LIKE :searchTerm');
            }
            conditions.add('(' + String.join(searchClauses, ' OR ') + ')');
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
        
        if (fieldExists('OccurredAt__c')) {
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
        }
        
        if (!conditions.isEmpty()) {
            soql += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        if (fieldExists('OccurredAt__c')) {
            soql += ' ORDER BY OccurredAt__c DESC, Id DESC';
        } else {
            soql += ' ORDER BY Id DESC';
        }
        soql += ' LIMIT :pageSize';
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

    private static Boolean fieldExists(String fieldName) {
        Map<String, SObjectField> fieldMap = Integration_Log__c.sObjectType.getDescribe().fields.getMap();
        return fieldMap.containsKey(fieldName);
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
        ]) {
            typeToSeverity.put(rule.ObservationType__c.toUpperCase(), rule.Severity__c);
        }

        List<String> summarySelects = new List<String>{'IntegrationCode__c code', 'ObservationType__c type', 'COUNT(Id) total'};
        List<String> summaryGroupBys = new List<String>{'IntegrationCode__c', 'ObservationType__c'};
        if (fieldExists('Normalized_Context__c')) {
            summarySelects.add('Normalized_Context__c norm');
            summaryGroupBys.add('Normalized_Context__c');
        }
        if (fieldExists('OccurredAt__c')) {
            summarySelects.add('MAX(OccurredAt__c) lastOccurred');
        }

        List<AggregateResult> aggregateResults = Database.query(
            'SELECT ' + String.join(summarySelects, ', ') + ' FROM Integration_Log__c WITH SECURITY_ENFORCED GROUP BY ' + String.join(summaryGroupBys, ', ')
        );

        for (AggregateResult ar : aggregateResults) {
            String norm = fieldExists('Normalized_Context__c') ? (String) ar.get('norm') : null;
            String code = (String) ar.get('code');
            String type = (String) ar.get('type');
            Integer count = (Integer) ar.get('total');
            Datetime lastOccurred = fieldExists('OccurredAt__c') ? (Datetime) ar.get('lastOccurred') : null;

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
            
            if (severity == 'ERROR' || severity == 'FATAL') {
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

