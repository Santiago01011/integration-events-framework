// ============================================================================
// STRESS TEST & GOVERNOR BOUNDARY SIMULATION (200-Event Ingestion & Limit Audit)
// ============================================================================

Long startTime = System.currentTimeMillis();
Integer initialCpu = Limits.getCpuTime();
Integer initialHeap = Limits.getHeapSize();
Integer initialQueries = Limits.getQueries();
Integer initialDml = Limits.getDmlStatements();

System.debug('=== [STRESS TEST START] ===');

// 1. Bulk Ingestion: 200 Integration Events in a single transaction
List<IEF_EventRequest> bulkRequests = new List<IEF_EventRequest>();
String nowIso = Datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

for (Integer i = 1; i <= 200; i++) {
    String code = Math.mod(i, 4) == 0 ? 'SAP_ECC' :
                  Math.mod(i, 4) == 1 ? 'STRIPE_PAYMENTS' :
                  Math.mod(i, 4) == 2 ? 'SFMC_CONTACTS' : 'NETSUITE_ERP';
    String obsType = Math.mod(i, 5) == 0 ? 'ORDER_SYNC_DISPATCHED' :
                     Math.mod(i, 5) == 1 ? 'PAYMENT_INTENT_SUCCEEDED' :
                     Math.mod(i, 5) == 2 ? 'SUBSCRIBER_SYNC' :
                     Math.mod(i, 5) == 3 ? 'INVOICE_CREATE_TIMEOUT' : 'INVENTORY_LOCK_FAILURE';
    String correlationId = 'STRESS-CORR-' + i + '-' + String.valueOf(Crypto.getRandomInteger()).substring(1, 6);
    String payload = '{"batchIndex": ' + i + ', "timestamp": "' + nowIso + '", "items": [{"sku": "PROD-' + i + '", "qty": ' + (i * 2) + ', "unitPrice": 49.99}], "authHeader": "Bearer token_masked_' + i + '"}';
    String message = 'Stress test synthetic load event #' + i + ' for integration ' + code;
    
    bulkRequests.add(new IEF_EventRequest(code, obsType, correlationId, payload, message));
}

// 2. Publish to EventBus
IntegrationEventPublisher.emit(bulkRequests);

Long durationMs = System.currentTimeMillis() - startTime;
Integer finalCpu = Limits.getCpuTime() - initialCpu;
Integer finalHeap = Limits.getHeapSize() - initialHeap;
Integer finalQueries = Limits.getQueries() - initialQueries;
Integer finalDml = Limits.getDmlStatements() - initialDml;

System.debug('=== [STRESS TEST TELEMETRY] ===');
System.debug('Events Emitted: ' + bulkRequests.size());
System.debug('Wall-Clock Execution Time: ' + durationMs + ' ms');
System.debug('Apex CPU Time Used: ' + finalCpu + ' ms / ' + Limits.getLimitCpuTime() + ' ms (' + (finalCpu * 100.0 / Limits.getLimitCpuTime()).setScale(2) + '%)');
System.debug('SOQL Queries Used: ' + finalQueries + ' / ' + Limits.getLimitQueries() + ' (Zero-SOQL CMDT Target)');
System.debug('DML Statements Used: ' + finalDml + ' / ' + Limits.getLimitDmlStatements() + ' (EventBus Publish Immediate)');
System.debug('Heap Size Delta: ' + finalHeap + ' bytes / ' + Limits.getLimitHeapSize() + ' bytes');
System.debug('===============================');
