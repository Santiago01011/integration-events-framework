/**
 * @description Generates mock logs across the current month for calendar visualization.
 * Run via: sf apex execute -f scripts/generateCalendarLogs.apex
 */
Datetime now = Datetime.now();
Integer currentDay = now.day();
Integer currentMonth = now.month();
Integer currentYear = now.year();

List<Integration_Log__c> logs = new List<Integration_Log__c>();

// Pattern: Day -> List of observation types with varying severities
// SUCCESS, RESPONSE_RECEIVED, BATCH_PROCESSED, SYNC_COMPLETED -> SUCCESS severity
// PARTIAL_RESPONSE, RETRY_ATTEMPT -> WARN severity
// EXCEPTION_THROWN, BATCH_ERROR -> ERROR severity
// SYNC_STARTED, DML_INSERT, REQUEST_DISPATCHED -> INFO severity

Map<Integer, List<String>> dayPatterns = new Map<Integer, List<String>>{
    // Week 1
    1 => new List<String>{ 'REQUEST_DISPATCHED', 'RESPONSE_RECEIVED', 'SYNC_STARTED' },
    2 => new List<String>{ 'REQUEST_DISPATCHED', 'RESPONSE_RECEIVED' },
    3 => new List<String>{ 'PARTIAL_RESPONSE', 'RETRY_ATTEMPT' },
    5 => new List<String>{ 'EXCEPTION_THROWN', 'REQUEST_DISPATCHED' },
    7 => new List<String>{ 'BATCH_PROCESSED', 'SYNC_COMPLETED' },
    // Week 2
    8 => new List<String>{ 'DML_INSERT', 'SYNC_STARTED' },
    9 => new List<String>{ 'REQUEST_DISPATCHED', 'RESPONSE_RECEIVED' },
    10 => new List<String>{ 'PARTIAL_RESPONSE', 'REQUEST_DISPATCHED' },
    12 => new List<String>{ 'EXCEPTION_THROWN', 'BATCH_ERROR' },
    14 => new List<String>{ 'RESPONSE_RECEIVED', 'SYNC_COMPLETED' },
    // Week 3
    15 => new List<String>{ 'DML_INSERT', 'REQUEST_DISPATCHED' },
    16 => new List<String>{ 'RETRY_ATTEMPT', 'PARTIAL_RESPONSE' },
    17 => new List<String>{ 'REQUEST_DISPATCHED', 'RESPONSE_RECEIVED', 'DML_INSERT' },
    19 => new List<String>{ 'BATCH_PROCESSED', 'SYNC_COMPLETED' },
    21 => new List<String>{ 'EXCEPTION_THROWN' },
    // Week 4 (and beyond if current month has more days)
    22 => new List<String>{ 'REQUEST_DISPATCHED', 'RESPONSE_RECEIVED' },
    23 => new List<String>{ 'PARTIAL_RESPONSE', 'RETRY_ATTEMPT', 'DML_INSERT' },
    24 => new List<String>{ 'SYNC_STARTED', 'SYNC_COMPLETED' },
    26 => new List<String>{ 'EXCEPTION_THROWN', 'BATCH_ERROR', 'REQUEST_DISPATCHED' },
    28 => new List<String>{ 'RESPONSE_RECEIVED', 'BATCH_PROCESSED' },
    29 => new List<String>{ 'DML_INSERT', 'REQUEST_DISPATCHED', 'RESPONSE_RECEIVED' },
    30 => new List<String>{ 'PARTIAL_RESPONSE', 'SYNC_COMPLETED' },
    31 => new List<String>{ 'REQUEST_DISPATCHED', 'RESPONSE_RECEIVED', 'SYNC_STARTED' }
};

List<String> integrationCodes = new List<String>{
    'HTTP-PED', 'HTTP-PROD', 'SAP-INV', 'SAP-INV-STOCK', 'SYS-AUDIT'
};

List<String> contexts = new List<String>{
    'Pedidos', 'Productos', 'Facturas', 'Inventario', 'Auditoria'
};

Integer correlationId = 1;

for (Integer day : dayPatterns.keySet()) {
    // Skip future days
    if (day > currentDay) {
        continue;
    }

    for (String obsType : dayPatterns.get(day)) {
        Integer intIndex = Math.mod(day, integrationCodes.size());
        Integer ctxIndex = Math.mod(day, contexts.size());

        Datetime occurredAt = Datetime.newInstance(
            currentYear,
            currentMonth,
            day,
            Integer.valueOf(Math.random() * 12) + 8, // 8am - 8pm
            Integer.valueOf(Math.random() * 60),
            0
        );

        logs.add(new Integration_Log__c(
            IntegrationCode__c = integrationCodes[intIndex],
            ObservationType__c = obsType,
            Normalized_Context__c = contexts[ctxIndex],
            CorrelationId__c = 'CAL-' + String.valueOf(correlationId++),
            OccurredAt__c = occurredAt,
            Context__c = '{"source":"calendar_mock","day":' + day + ',"type":"' + obsType + '"}'
        ));
    }
}

// Add some extra noise logs for today to make today look active
Integer todayExtra = 5;
for (Integer i = 0; i < todayExtra; i++) {
    logs.add(new Integration_Log__c(
        IntegrationCode__c = integrationCodes[Math.mod(i, integrationCodes.size())],
        ObservationType__c = 'RESPONSE_RECEIVED',
        Normalized_Context__c = contexts[Math.mod(i, contexts.size())],
        CorrelationId__c = 'CAL-TODAY-' + i,
        OccurredAt__c = Datetime.now().addMinutes(-i * 5),
        Context__c = '{"source":"calendar_mock","extra":true}'
    ));
}

insert logs;
System.debug('Inserted ' + logs.size() + ' calendar mock logs across days: ' + dayPatterns.keySet());
