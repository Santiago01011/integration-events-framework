/**
 * @description Coordinate logic for the Integration Health Dashboard.
 */
public with sharing class IntegrationHealthService {
  /**
   * @description Fetches paged logs based on filters.
   * Uses primitive parameters for pagination to avoid Datetime deserialization issues in Aura/LWC.
   * @param pageSize The number of logs to fetch
   * @param search The search term
   * @param fromOccurredAtStr The start date filter (ISO string)
   * @param toOccurredAtStr The end date filter (ISO string)
   * @param lastOccurredAtStr Pagination cursor: last record's OccurredAt as ISO string
   * @param lastId Pagination cursor: last record's Id
   * @param correlationId The correlation ID filter
   * @param observationType The observation type filter
   * @param integrationCode The integration code filter
   * @return IntegrationHealthWrappers.IntegrationLogPage The paged logs
   */
  public static IntegrationHealthWrappers.IntegrationLogPage getPagedLogs(
    Integer pageSize,
    String search,
    String fromOccurredAtStr,
    String toOccurredAtStr,
    String lastOccurredAtStr,
    Id lastId,
    String correlationId,
    String observationType,
    String integrationCode
  ) {
    pageSize = (pageSize == null || pageSize <= 0) ? 20 : pageSize;

    Datetime lastOccurred = null;
    if (String.isNotBlank(lastOccurredAtStr)) {
      lastOccurred = (Datetime) JSON.deserialize(
        '"' + lastOccurredAtStr + '"',
        Datetime.class
      );
    }

    List<Integration_Log__c> records = IntegrationHealthSelector.queryLogs(
      pageSize + 1,
      search,
      fromOccurredAtStr,
      toOccurredAtStr,
      lastOccurred,
      lastId,
      correlationId,
      observationType,
      integrationCode
    );

    IntegrationHealthWrappers.IntegrationLogPage page = new IntegrationHealthWrappers.IntegrationLogPage();

    if (records.size() > pageSize) {
      page.hasMore = true;
      records.remove(records.size() - 1);
    } else {
      page.hasMore = false;
    }

    page.records = records;

    for (idhIntegration_Evaluation_Rule__mdt rule : [
      SELECT ObservationType__c, Severity__c
      FROM idhIntegration_Evaluation_Rule__mdt
    ]) {
      page.typeToSeverity.put(
        rule.ObservationType__c.toUpperCase(),
        rule.Severity__c
      );
    }

    if (!records.isEmpty()) {
      Integration_Log__c lastRecord = records[records.size() - 1];
      Datetime lastRecOccurred = IntegrationHealthSelector.fieldExists(
          'OccurredAt__c'
        )
        ? (Datetime) lastRecord.get('OccurredAt__c')
        : null;
      page.lastOccurredAt = lastRecOccurred != null
        ? lastRecOccurred.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
        : null;
      page.lastId = lastRecord.Id;
    }

    return page;
  }

  /**
   * @description Fetches details for a specific log, including severity rules.
   * Used by the Integration Log Detail component to display the details of a single log.
   * @param logId The ID of the log to retrieve
   * @return IntegrationHealthWrappers.LogDetailWrapper The log details
   */
  public static IntegrationHealthWrappers.LogDetailWrapper getLogDetail(
    Id logId
  ) {
    if (logId == null) {
      throw new AuraHandledException('Log Id is required');
    }

    Integration_Log__c log = IntegrationHealthSelector.getLogById(logId);
    if (log == null) {
      throw new AuraHandledException('Log not found');
    }

    IntegrationHealthWrappers.LogDetailWrapper wrapper = new IntegrationHealthWrappers.LogDetailWrapper();
    wrapper.record = log;

    List<idhIntegration_Evaluation_Rule__mdt> rules = IntegrationHealthSelector.getEvaluationRules(
      log.ObservationType__c
    );
    wrapper.severity = !rules.isEmpty() ? rules[0].Severity__c : null;

    return wrapper;
  }

  /**
   * @description Aggregates logs into integration summaries.
   * Used by the Integration Health Dashboard LWC to display the integration summaries tab.
   * @param includeUnregistered Whether to include unregistered integrations
   * @param expandByAttributes Whether to expand by attributes
   * @return List<IntegrationHealthWrappers.IntegrationSummary> The integration summaries
   */
  public static List<IntegrationHealthWrappers.IntegrationSummary> getIntegrationSummaries(
    Boolean includeUnregistered,
    Boolean expandByAttributes
  ) {
    includeUnregistered = (includeUnregistered == null)
      ? false
      : includeUnregistered;
    expandByAttributes = (expandByAttributes == null)
      ? false
      : expandByAttributes;
    Map<String, IntegrationHealthWrappers.IntegrationSummary> summaryMap = new Map<String, IntegrationHealthWrappers.IntegrationSummary>();

    Map<String, idhIntegration_Definition__mdt> registryMap = IntegrationHealthSelector.getIntegrationDefinitions();
    List<AggregateResult> aggregateResults = IntegrationHealthSelector.getLogSummaries();

    Map<String, String> typeToSeverity = new Map<String, String>();
    for (idhIntegration_Evaluation_Rule__mdt rule : [
      SELECT ObservationType__c, Severity__c
      FROM idhIntegration_Evaluation_Rule__mdt
    ]) {
      typeToSeverity.put(
        rule.ObservationType__c.toUpperCase(),
        rule.Severity__c
      );
    }

    for (AggregateResult ar : aggregateResults) {
      String norm = IntegrationHealthSelector.fieldExists(
          'Normalized_Context__c'
        )
        ? (String) ar.get('norm')
        : null;
      String code = (String) ar.get('code');
      String type = (String) ar.get('type');
      Integer count = (Integer) ar.get('total');
      Datetime lastOccurred = IntegrationHealthSelector.fieldExists(
          'OccurredAt__c'
        )
        ? (Datetime) ar.get('lastOccurred')
        : null;

      Boolean isRegistered = registryMap.containsKey(code.toUpperCase());

      if (!includeUnregistered && !isRegistered) {
        continue;
      }

      idhIntegration_Definition__mdt regEntry = isRegistered
        ? registryMap.get(code.toUpperCase())
        : null;

      String groupingKey;
      String finalDisplayName;
      String componentLabel;
      String direction = (regEntry != null) ? regEntry.Direction__c : null;
      String transport = (regEntry != null) ? regEntry.Transport__c : null;

      String currentLabel = (regEntry != null &&
        String.isNotBlank(regEntry.Label__c))
        ? regEntry.Label__c
        : (String.isNotBlank(norm) ? norm : code);

      if (regEntry != null && String.isNotBlank(regEntry.Group__c)) {
        if (expandByAttributes) {
          List<String> keyParts = new List<String>{ regEntry.Group__c };
          if (String.isNotBlank(direction))
            keyParts.add(direction);
          if (String.isNotBlank(transport))
            keyParts.add(transport);
          groupingKey = String.join(keyParts, '|');

          List<String> nameParts = new List<String>{ regEntry.Group__c };
          if (String.isNotBlank(direction))
            nameParts.add(direction);
          if (String.isNotBlank(transport))
            nameParts.add('(' + transport + ')');
          finalDisplayName = String.join(nameParts, ' · ');
        } else {
          groupingKey = regEntry.Group__c;
          finalDisplayName = regEntry.Group__c;
        }
      } else {
        groupingKey = String.isNotBlank(norm) ? norm : code;
        finalDisplayName = currentLabel;
      }

      componentLabel = currentLabel;

      if (!summaryMap.containsKey(groupingKey)) {
        IntegrationHealthWrappers.IntegrationSummary summary = new IntegrationHealthWrappers.IntegrationSummary();
        summary.integrationCode = groupingKey;
        summary.displayName = finalDisplayName;
        summary.groupName = (regEntry != null) ? regEntry.Group__c : null;
        summary.transport = transport;
        summary.direction = direction;
        summary.isRegistered = isRegistered;
        summaryMap.put(groupingKey, summary);
      }

      IntegrationHealthWrappers.IntegrationSummary summary = summaryMap.get(
        groupingKey
      );

      if (!summary.componentLabels.contains(componentLabel)) {
        summary.componentLabels.add(componentLabel);
      }

      summary.totalEvents += count;
      if (
        summary.lastOccurredAt == null ||
        (lastOccurred != null &&
        lastOccurred > summary.lastOccurredAt)
      ) {
        summary.lastOccurredAt = lastOccurred;
      }

      String severity = typeToSeverity.containsKey(type.toUpperCase())
        ? typeToSeverity.get(type.toUpperCase())
        : null;
      if (severity == 'ERROR' || severity == 'FATAL') {
        summary.errorCount += count;
      } else {
        summary.successCount += count;
      }
    }

    return summaryMap.values();
  }

  /**
   * @description Fetches registry information for the admin panel.
   */
  public static List<IntegrationHealthWrappers.RegistryEntry> getRegistryInfo() {
    Map<String, IntegrationHealthWrappers.RegistryEntry> entryMap = new Map<String, IntegrationHealthWrappers.RegistryEntry>();
    Map<String, idhIntegration_Definition__mdt> registryMap = IntegrationHealthSelector.getIntegrationDefinitions();

    for (String codeUpper : registryMap.keySet()) {
      idhIntegration_Definition__mdt mdt = registryMap.get(codeUpper);
      IntegrationHealthWrappers.RegistryEntry entry = new IntegrationHealthWrappers.RegistryEntry();
      entry.integrationCode = mdt.IntegrationCode__c;
      entry.label = mdt.Label__c;
      entry.groupName = mdt.Group__c;
      entry.direction = mdt.Direction__c;
      entry.transport = mdt.Transport__c;
      entry.isEnabled = mdt.Enabled__c;
      entry.isRegistered = true;
      entry.eventCount = 0;
      entryMap.put(codeUpper, entry);
    }

    for (AggregateResult ar : IntegrationHealthSelector.getLogCountsByCode()) {
      String code = (String) ar.get('code');
      Integer count = (Integer) ar.get('total');
      String codeUpper = code.toUpperCase();

      if (entryMap.containsKey(codeUpper)) {
        entryMap.get(codeUpper).eventCount = count;
      } else {
        IntegrationHealthWrappers.RegistryEntry entry = new IntegrationHealthWrappers.RegistryEntry();
        entry.integrationCode = code;
        entry.label = code;
        entry.isRegistered = false;
        entry.isEnabled = true;
        entry.eventCount = count;
        entryMap.put(codeUpper, entry);
      }
    }

    List<IntegrationHealthWrappers.RegistryEntry> result = entryMap.values();
    result.sort();
    return result;
  }

  /**
   * @description Fetches available filter options.
   * Used by ihdFilters LWC component to populate the filter options.
   * @return IntegrationHealthWrappers.FilterOptions The filter options
   */
  public static IntegrationHealthWrappers.FilterOptions getFilterOptions() {
    IntegrationHealthWrappers.FilterOptions filters = new IntegrationHealthWrappers.FilterOptions();
    for (AggregateResult ar : [
      SELECT ObservationType__c type
      FROM Integration_Log__c
      GROUP BY ObservationType__c
    ]) {
      filters.observationTypes.add((String) ar.get('type'));
    }
    for (AggregateResult ar : [
      SELECT IntegrationCode__c code
      FROM Integration_Log__c
      WHERE IntegrationCode__c != NULL
      GROUP BY IntegrationCode__c
    ]) {
      filters.integrationCodes.add((String) ar.get('code'));
    }
    return filters;
  }

  public static String getEventChannel() {
    String eventName = IntegrationEvent__e.SObjectType.getDescribe().getName();
    return '/event/' + eventName;
  }

  public static void deleteLog(Id logId) {
    if (logId == null)
      return;
    delete [SELECT Id FROM Integration_Log__c WHERE Id = :logId];
  }

  public static void updateLogObservation(Id logId, String newType) {
    if (logId == null || String.isBlank(newType))
      return;
    update new Integration_Log__c(Id = logId, ObservationType__c = newType);
  }
}
