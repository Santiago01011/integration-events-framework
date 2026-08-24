/**
 * @description Card provider for the Severity Breakdown plugin.
 * Implements IEF_CardPlugin and owns its aggregate queries so core
 * remains plugin-agnostic (D1 Option B). Exposes @AuraEnabled getCardData.
 *
 * Filter contract (C3):
 * - Supported and honored: search, observationType, integrationCode,
 *   correlationId, fromOccurredAt, toOccurredAt. All are optional; when
 *   provided the returned aggregates respect the filter. Time range is
 *   applied to OccurredAt__c when the field exists, otherwise to CreatedDate.
 * - Unsupported: none — all dashboard filter keys are honored. Any future
 *   filter key not listed here is intentionally ignored until implemented
 *   and will be documented here when added.
 */
public with sharing class IEF_SeverityCardPlugin implements IEF_CardPlugin {
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.SeverityCountEntry> getCardData(
    Map<String, Object> filters
  ) {
    Map<String, Object> safeFilters = filters != null
      ? filters
      : new Map<String, Object>();

    List<String> conditions = new List<String>();
    Map<String, Object> bindMap = new Map<String, Object>();

    String search = getString(safeFilters, 'search');
    String observationType = getString(safeFilters, 'observationType');
    String integrationCode = getString(safeFilters, 'integrationCode');
    String correlationId = getString(safeFilters, 'correlationId');
    Datetime fromDt = parseIso(safeFilters.get('fromOccurredAt'));
    if (fromDt == null) {
      fromDt = parseIso(safeFilters.get('fromOccurredAtStr'));
    }
    Datetime toDt = parseIso(safeFilters.get('toOccurredAt'));
    if (toDt == null) {
      toDt = parseIso(safeFilters.get('toOccurredAtStr'));
    }

    Boolean hasOccurredAt = hasField('OccurredAt__c');
    String dateField = hasOccurredAt ? 'OccurredAt__c' : 'CreatedDate';

    if (String.isNotBlank(search)) {
      String searchTerm = '%' + search + '%';
      List<String> searchClauses = new List<String>{
        'ObservationType__c LIKE :searchTerm',
        'IntegrationCode__c LIKE :searchTerm',
        'CorrelationId__c LIKE :searchTerm'
      };
      if (hasField('Normalized_Context__c')) {
        searchClauses.add('Normalized_Context__c LIKE :searchTerm');
      }
      conditions.add('(' + String.join(searchClauses, ' OR ') + ')');
      bindMap.put('searchTerm', searchTerm);
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
    if (String.isNotBlank(correlationId)) {
      conditions.add('CorrelationId__c = :correlationId');
      bindMap.put('correlationId', correlationId);
    }
    if (fromDt != null) {
      conditions.add(dateField + ' >= :fromDt');
      bindMap.put('fromDt', fromDt);
    }
    if (toDt != null) {
      conditions.add(dateField + ' <= :toDt');
      bindMap.put('toDt', toDt);
    }

    String query = 'SELECT ObservationType__c obsType, COUNT(Id) total FROM Integration_Log__c';
    if (!conditions.isEmpty()) {
      query += ' WHERE ' + String.join(conditions, ' AND ');
    }
    query += ' WITH USER_MODE GROUP BY ObservationType__c';

    List<AggregateResult> results = (List<AggregateResult>) Database.queryWithBinds(
      query,
      bindMap,
      AccessLevel.USER_MODE
    );

    if (results.isEmpty()) {
      return new List<IntegrationHealthWrappers.SeverityCountEntry>();
    }

    Map<String, idhIntegration_Evaluation_Rule__mdt> rulesByType = getRulesByType();
    Map<String, Integer> severityCounts = new Map<String, Integer>();
    Integer totalEvents = 0;

    for (AggregateResult ar : results) {
      String obsType = (String) ar.get('obsType');
      Integer count = (Integer) ar.get('total');
      totalEvents += count;
      String severity = resolveSeverity(obsType, rulesByType);
      Integer cur = severityCounts.containsKey(severity)
        ? severityCounts.get(severity)
        : 0;
      severityCounts.put(severity, cur + count);
    }

    List<IntegrationHealthWrappers.SeverityCountEntry> entries = new List<IntegrationHealthWrappers.SeverityCountEntry>();
    for (String sev : severityCounts.keySet()) {
      IntegrationHealthWrappers.SeverityCountEntry e = new IntegrationHealthWrappers.SeverityCountEntry();
      e.severity = sev;
      e.count = severityCounts.get(sev);
      e.percentage = totalEvents > 0
        ? (e.count * 100.0 / totalEvents).setScale(1)
        : 0;
      entries.add(e);
    }
    return entries;
  }

  public Object getData(Map<String, Object> filters) {
    return getCardData(filters);
  }

  public String getCardName() {
    return 'Severity Breakdown';
  }

  public String getCardDescription() {
    return 'Distribution of events by severity derived from evaluation rules.';
  }

  public String getComponentName() {
    return 'c-iefSeverityCardImpl';
  }

  public Integer getOrder() {
    return 2;
  }

  private static String getString(Map<String, Object> m, String key) {
    if (m == null || !m.containsKey(key) || m.get(key) == null) {
      return null;
    }
    return String.valueOf(m.get(key));
  }

  private static Datetime parseIso(Object raw) {
    if (raw == null) {
      return null;
    }
    String s = String.valueOf(raw);
    if (String.isBlank(s)) {
      return null;
    }
    try {
      return (Datetime) JSON.deserialize('"' + s + '"', Datetime.class);
    } catch (Exception e) {
      try {
        return Datetime.valueOf(s);
      } catch (Exception ex) {
        return null;
      }
    }
  }

  private static Boolean hasField(String fieldName) {
    return Schema.SObjectType.Integration_Log__c.fields.getMap()
      .containsKey(fieldName);
  }

  private static Map<String, idhIntegration_Evaluation_Rule__mdt> getRulesByType() {
    Map<String, idhIntegration_Evaluation_Rule__mdt> m = new Map<String, idhIntegration_Evaluation_Rule__mdt>();
    for (idhIntegration_Evaluation_Rule__mdt r : [
      SELECT ObservationType__c, Severity__c
      FROM idhIntegration_Evaluation_Rule__mdt
    ]) {
      m.put(r.ObservationType__c.toUpperCase(), r);
    }
    return m;
  }

  private static String resolveSeverity(
    String obsType,
    Map<String, idhIntegration_Evaluation_Rule__mdt> rulesByType
  ) {
    if (String.isBlank(obsType)) {
      return 'SUCCESS';
    }
    idhIntegration_Evaluation_Rule__mdt rule = rulesByType.get(
      obsType.toUpperCase()
    );
    return rule != null ? rule.Severity__c : 'SUCCESS';
  }
}
