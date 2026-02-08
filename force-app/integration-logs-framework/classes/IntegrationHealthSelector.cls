/**
 * @description Selector class for Integration Health logs and metadata.
 * Serves as the data access layer for the Integration Health LWC components.
 * Implements the Selector Pattern to abstract the data access layer from the service layer.
 */
public with sharing class IntegrationHealthSelector {
  private static Map<String, SObjectField> cachedFieldMap = Integration_Log__c.sObjectType.getDescribe()
    .fields.getMap();
  private static Map<String, Boolean> fieldExistsCache = new Map<String, Boolean>();

  public static List<Integration_Log__c> queryLogs(
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
      fromOccurredAt = (Datetime) JSON.deserialize(
        '\"' + fromOccurredAtStr + '\"',
        Datetime.class
      );
    }
    if (String.isNotBlank(toOccurredAtStr)) {
      toOccurredAt = (Datetime) JSON.deserialize(
        '\"' + toOccurredAtStr + '\"',
        Datetime.class
      );
    }

    List<String> detailFields = new List<String>{
      'Id',
      'ObservationType__c',
      'IntegrationCode__c',
      'CorrelationId__c',
      'OccurredAt__c',
      'CreatedDate'
    };

    if (fieldExists('Normalized_Context__c')) {
      detailFields.add('Normalized_Context__c');
    }

    String soql =
      'SELECT ' +
      String.join(detailFields, ',') +
      ' FROM Integration_Log__c';

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
      conditions.add('CorrelationId__c = :correlationId');
      bindMap.put('correlationId', correlationId);
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
    }

    if (lastId != null) {
      if (lastOccurredAt != null) {
        conditions.add(
          '(OccurredAt__c < :lastOccurredAt OR (OccurredAt__c = :lastOccurredAt AND Id < :lastId))'
        );
        bindMap.put('lastOccurredAt', lastOccurredAt);
      } else {
        conditions.add(
          '(OccurredAt__c = NULL AND Id < :lastId) OR (OccurredAt__c != NULL)'
        );
      }
      bindMap.put('lastId', lastId);
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

  /**
   * @description Get a single log by ID
   * Used by the Integration Log Detail component to display the details of a single log.
   * @param logId The ID of the log to retrieve
   * @return Integration_Log__c The log with the specified ID
   */
  public static Integration_Log__c getLogById(Id logId) {
    List<String> detailFields = new List<String>{
      'Id',
      'ObservationType__c',
      'IntegrationCode__c',
      'Url__c',
      'Method__c',
      'HttpStatus__c',
      'Duration__c',
      'CorrelationId__c',
      'Context__c',
      'Request_Body__c',
      'Response_Body__c',
      'CreatedDate'
    };

    if (fieldExists('OccurredAt__c')) {
      detailFields.add('OccurredAt__c');
    }
    if (fieldExists('Normalized_Context__c')) {
      detailFields.add('Normalized_Context__c');
    }

    String accessibleFields = getAccessibleFieldsAsCsv(detailFields);
    String query =
      'SELECT ' +
      accessibleFields +
      ' FROM Integration_Log__c WHERE Id = :logId';
    List<Integration_Log__c> logs = Database.query(
      query,
      AccessLevel.USER_MODE
    );
    return logs.isEmpty() ? null : logs[0];
  }

  /**
   * @description Get the evaluation rules for a specific observation type
   * @param observationType The type of observation to get the evaluation rules for
   * @return List<idhIntegration_Evaluation_Rule__mdt> The evaluation rules for the specified observation type
   */
  public static List<idhIntegration_Evaluation_Rule__mdt> getEvaluationRules(
    String observationType
  ) {
    return [
      SELECT Severity__c
      FROM idhIntegration_Evaluation_Rule__mdt
      WHERE ObservationType__c = :observationType
      LIMIT 1
    ];
  }

  public static Map<String, idhIntegration_Definition__mdt> getIntegrationDefinitions() {
    Map<String, idhIntegration_Definition__mdt> registryMap = new Map<String, idhIntegration_Definition__mdt>();
    for (idhIntegration_Definition__mdt entry : [
      SELECT
        DeveloperName,
        Label__c,
        IntegrationCode__c,
        Group__c,
        Direction__c,
        Transport__c,
        Enabled__c
      FROM idhIntegration_Definition__mdt
    ]) {
      registryMap.put(entry.IntegrationCode__c.toUpperCase(), entry);
    }
    return registryMap;
  }

  public static List<AggregateResult> getLogSummaries() {
    List<String> summarySelects = new List<String>{
      'IntegrationCode__c code',
      'ObservationType__c type',
      'COUNT(Id) total'
    };
    List<String> summaryGroupBys = new List<String>{
      'IntegrationCode__c',
      'ObservationType__c'
    };
    if (fieldExists('Normalized_Context__c')) {
      summarySelects.add('Normalized_Context__c norm');
      summaryGroupBys.add('Normalized_Context__c');
    }
    if (fieldExists('OccurredAt__c')) {
      summarySelects.add('MAX(OccurredAt__c) lastOccurred');
    }

    String query =
      'SELECT ' +
      String.join(summarySelects, ', ') +
      ' FROM Integration_Log__c WITH SECURITY_ENFORCED GROUP BY ' +
      String.join(summaryGroupBys, ', ') +
      ' LIMIT 2000';
    return Database.query(query);
  }

  public static List<AggregateResult> getLogCountsByCode() {
    return [
      SELECT IntegrationCode__c code, COUNT(Id) total
      FROM Integration_Log__c
      WHERE IntegrationCode__c != NULL
      GROUP BY IntegrationCode__c
    ];
  }

  /**
   * @description Check if the current user has delete permission on the log object
   * Users with delete permission on the log object are considered admin users of the integration logs framework.
   * This works with Permission Sets, Permission Set Groups, and Profiles.
   * @return Boolean
   */
  public static Boolean isAdminUser() {
    return Schema.sObjectType.Integration_Log__c.isDeletable();
  }

  /**
   * @description Check if a field exists on the log object
   * @param fieldName The name of the field to check
   * @return Boolean
   */
  public static Boolean fieldExists(String fieldName) {
    return cachedFieldMap.containsKey(fieldName);
  }

  /**
   * @description Get the accessible fields as a CSV string
   * @param fieldsToCheck The list of fields to check
   * @return String The CSV string of accessible fields
   */
  private static String getAccessibleFieldsAsCsv(List<String> fieldsToCheck) {
    List<String> accessibleFields = new List<String>();
    DescribeSObjectResult sObjectDescribe = Integration_Log__c.sObjectType.getDescribe();
    Map<String, SObjectField> fieldsMap = sObjectDescribe.fields.getMap();

    for (String fieldName : fieldsToCheck) {
      if (
        fieldsMap.containsKey(fieldName) &&
        fieldsMap.get(fieldName).getDescribe().isAccessible()
      ) {
        accessibleFields.add(fieldName);
      }
    }
    return String.join(accessibleFields, ',');
  }
}
