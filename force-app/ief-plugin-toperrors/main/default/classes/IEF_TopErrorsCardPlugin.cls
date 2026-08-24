/**
 * @description Card provider for the Top Error Integrations plugin.
 * Implements IEF_CardPlugin with @AuraEnabled getCardData(filters).
 * Aggregates error counts per integrationCode and folds hourly-trend
 * logic into entry.trend (D1 trend placement — trend indicator deleted
 * in D7, so trend is now part of this card). Core remains plugin-agnostic.
 *
 * Filter contract (C3):
 * - Supported and honored: search, observationType, integrationCode,
 *   correlationId, fromOccurredAt, toOccurredAt, topN. All are optional;
 *   aggregates respect the provided range. Time range applied to
 *   OccurredAt__c when present, otherwise CreatedDate. topN defaults to 5
 *   and may be supplied inside the filters map as Integer/Decimal/String
 *   under key 'topN'; when absent the provider uses 5.
 * - Unsupported: custom trend window (hours). Trend is fixed to the last
 *   4 hours filtered by the same dashboard filters; a custom hours filter
 *   is intentionally unsupported and ignored.
 */
public with sharing class IEF_TopErrorsCardPlugin implements IEF_CardPlugin {
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.TopErrorIntegration> getCardData(
    Map<String, Object> filters
  ) {
    Map<String, Object> safeFilters = filters != null
      ? filters
      : new Map<String, Object>();

    Integer topN = extractTopN(safeFilters);
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
      List<String> clauses = new List<String>{
        'ObservationType__c LIKE :searchTerm',
        'IntegrationCode__c LIKE :searchTerm',
        'CorrelationId__c LIKE :searchTerm'
      };
      if (hasField('Normalized_Context__c')) {
        clauses.add('Normalized_Context__c LIKE :searchTerm');
      }
      conditions.add('(' + String.join(clauses, ' OR ') + ')');
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

    String query = 'SELECT IntegrationCode__c code, ObservationType__c type, COUNT(Id) total FROM Integration_Log__c';
    if (!conditions.isEmpty()) {
      query += ' WHERE ' + String.join(conditions, ' AND ');
    }
    query += ' GROUP BY IntegrationCode__c, ObservationType__c';

    List<AggregateResult> results = (List<AggregateResult>) Database.queryWithBinds(
      query,
      bindMap,
      AccessLevel.USER_MODE
    );

    if (results.isEmpty()) {
      return new List<IntegrationHealthWrappers.TopErrorIntegration>();
    }

    Map<String, idhIntegration_Evaluation_Rule__mdt> rulesByType = getRulesByType();
    Map<String, IntegrationHealthWrappers.TopErrorIntegration> integrationMap = new Map<String, IntegrationHealthWrappers.TopErrorIntegration>();

    for (AggregateResult ar : results) {
      String code = (String) ar.get('code');
      String type = (String) ar.get('type');
      Integer cnt = (Integer) ar.get('total');
      if (String.isBlank(code)) {
        continue;
      }
      String severity = resolveSeverity(type, rulesByType);
      if (!integrationMap.containsKey(code)) {
        IntegrationHealthWrappers.TopErrorIntegration entry = new IntegrationHealthWrappers.TopErrorIntegration();
        entry.integrationCode = code;
        entry.displayName = code;
        integrationMap.put(code, entry);
      }
      IntegrationHealthWrappers.TopErrorIntegration entry = integrationMap.get(
        code
      );
      entry.totalEvents += cnt;
      if (severity == 'ERROR' || severity == 'FATAL') {
        entry.errorCount += cnt;
      }
    }

    List<IntegrationHealthWrappers.TopErrorIntegration> ranked = sortByErrorCount(
      integrationMap.values()
    );

    List<IntegrationHealthWrappers.TopErrorIntegration> topEntries = new List<IntegrationHealthWrappers.TopErrorIntegration>();
    for (Integer i = 0; i < topN && i < ranked.size(); i++) {
      topEntries.add(ranked[i]);
    }

    String globalTrend = computeGlobalTrend(
      conditions,
      bindMap,
      dateField,
      rulesByType
    );
    for (IntegrationHealthWrappers.TopErrorIntegration e : topEntries) {
      e.trend = globalTrend;
    }

    return topEntries;
  }

  public Object getData(Map<String, Object> filters) {
    return getCardData(filters);
  }

  public String getCardName() {
    return 'Top Error Integrations';
  }

  public String getCardDescription() {
    return 'Integrations ranked by error count with hourly trend indicator.';
  }

  public String getComponentName() {
    return 'c-iefTopErrorsCardImpl';
  }

  public Integer getOrder() {
    return 1;
  }

  private static Integer extractTopN(Map<String, Object> filters) {
    Integer topN = 5;
    if (filters.containsKey('topN') && filters.get('topN') != null) {
      Object raw = filters.get('topN');
      try {
        if (raw instanceof Integer) {
          topN = (Integer) raw;
        } else if (raw instanceof Decimal) {
          topN = ((Decimal) raw).intValue();
        } else if (raw instanceof Long) {
          topN = ((Long) raw).intValue();
        } else {
          topN = Integer.valueOf(String.valueOf(raw));
        }
      } catch (Exception e) {
        topN = 5;
      }
    }
    if (topN == null || topN <= 0) {
      topN = 5;
    }
    return topN;
  }

  private static String computeGlobalTrend(
    List<String> baseConditions,
    Map<String, Object> baseBindMap,
    String dateField,
    Map<String, idhIntegration_Evaluation_Rule__mdt> rulesByType
  ) {
    Datetime sinceTime = Datetime.now().addHours(-4);
    List<String> conditions = new List<String>(baseConditions);
    Map<String, Object> bindMap = new Map<String, Object>(baseBindMap);
    conditions.add('CreatedDate >= :sinceTime');
    bindMap.put('sinceTime', sinceTime);

    String query = 'SELECT HOUR_IN_DAY(CreatedDate) hour, ObservationType__c type, COUNT(Id) total FROM Integration_Log__c';
    if (!conditions.isEmpty()) {
      query += ' WHERE ' + String.join(conditions, ' AND ');
    }
    query += ' GROUP BY HOUR_IN_DAY(CreatedDate), ObservationType__c ORDER BY HOUR_IN_DAY(CreatedDate) ASC';

    List<AggregateResult> results;
    try {
      results = (List<AggregateResult>) Database.queryWithBinds(
        query,
        bindMap,
        AccessLevel.USER_MODE
      );
    } catch (Exception e) {
      return 'flat';
    }

    if (results.isEmpty()) {
      return 'flat';
    }

    Map<Integer, IntegrationHealthWrappers.TrendPoint> pointMap = new Map<Integer, IntegrationHealthWrappers.TrendPoint>();
    for (AggregateResult ar : results) {
      Integer hour = (Integer) ar.get('hour');
      String type = (String) ar.get('type');
      Integer cnt = (Integer) ar.get('total');
      String severity = resolveSeverity(type, rulesByType);
      if (!pointMap.containsKey(hour)) {
        IntegrationHealthWrappers.TrendPoint p = new IntegrationHealthWrappers.TrendPoint();
        p.hour = String.valueOf(hour).leftPad(2, '0') + ':00';
        pointMap.put(hour, p);
      }
      IntegrationHealthWrappers.TrendPoint p = pointMap.get(hour);
      p.total += cnt;
      if (severity == 'ERROR' || severity == 'FATAL') {
        p.errors += cnt;
      }
    }

    List<Integer> sortedHours = new List<Integer>(pointMap.keySet());
    sortedHours.sort();
    List<IntegrationHealthWrappers.TrendPoint> points = new List<IntegrationHealthWrappers.TrendPoint>();
    for (Integer h : sortedHours) {
      points.add(pointMap.get(h));
    }

    if (points.size() >= 2) {
      IntegrationHealthWrappers.TrendPoint last = points[points.size() - 1];
      IntegrationHealthWrappers.TrendPoint prev = points[points.size() - 2];
      if (prev.total > 0) {
        Decimal delta = ((last.total - prev.total) *
          100.0 /
          prev.total)
          .setScale(1);
        if (delta > 0) {
          return 'up';
        } else if (delta < 0) {
          return 'down';
        }
      }
    }
    return 'flat';
  }

  private static List<IntegrationHealthWrappers.TopErrorIntegration> sortByErrorCount(
    List<IntegrationHealthWrappers.TopErrorIntegration> entries
  ) {
    List<SortableEntry> sortable = new List<SortableEntry>();
    for (IntegrationHealthWrappers.TopErrorIntegration e : entries) {
      sortable.add(new SortableEntry(e));
    }
    sortable.sort();
    List<IntegrationHealthWrappers.TopErrorIntegration> sorted = new List<IntegrationHealthWrappers.TopErrorIntegration>();
    for (SortableEntry se : sortable) {
      sorted.add(se.entry);
    }
    return sorted;
  }

  private class SortableEntry implements Comparable {
    IntegrationHealthWrappers.TopErrorIntegration entry;
    SortableEntry(IntegrationHealthWrappers.TopErrorIntegration e) {
      this.entry = e;
    }
    public Integer compareTo(Object o) {
      SortableEntry other = (SortableEntry) o;
      return other.entry.errorCount - this.entry.errorCount;
    }
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
