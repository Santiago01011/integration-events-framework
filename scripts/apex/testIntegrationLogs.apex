/**
 * Test script for Integration Events Framework
 * Simulates events for multiple integrations to test the framework behavior
 */

// Generate a unique correlation ID for this test run
String correlationId =
  'CORR-TEST-' + String.valueOf(System.currentTimeMillis());

// Integration 1: Productos (Products) - Successful flow
System.debug('Starting Productos integration simulation');

// Emit start event
IntegrationEventPublisher.emit(
  'testing-Productos',
  'BATCH_START',
  correlationId,
  null,
  '{"integration":"Productos Sync","mode":"LIVE","totalExpected":100}'
);

// Emit HTTP request
String requestEventId = 'REQ-' + correlationId + '-1';
IntegrationEventPublisher.emit(
  'testing-Productos',
  'HTTP_REQUEST',
  correlationId,
  null,
  '{"url":"https://api.example.com/products","method":"GET","headers":{"Authorization":"Bearer token"}}'
);

// Emit successful HTTP response
IntegrationEventPublisher.emit(
  'testing-Productos',
  'HTTP_RESPONSE',
  correlationId,
  requestEventId,
  '{"statusCode":200,"responseTime":150,"recordsReturned":50}'
);

// Emit processing event
IntegrationEventPublisher.emit(
  'testing-Productos',
  'DATA_PROCESSING',
  correlationId,
  null,
  '{"recordsProcessed":50,"recordsUpserted":45,"recordsSkipped":5}'
);

// Emit batch completion
IntegrationEventPublisher.emit(
  'testing-Productos',
  'BATCH_COMPLETE',
  correlationId,
  null,
  '{"totalProcessed":50,"success":true}'
);

System.debug('Productos integration simulation completed successfully');

// Integration 2: Pedidos (Orders) - Flow with error
System.debug('Starting Pedidos integration simulation');

// Emit start event for Pedidos
String pedidosCorrelationId =
  'CORR-PEDIDOS-' + String.valueOf(System.currentTimeMillis());
IntegrationEventPublisher.emit(
  'testing-Pedidos',
  'BATCH_START',
  pedidosCorrelationId,
  null,
  '{"integration":"Pedidos Sync","mode":"LIVE","totalExpected":25}'
);

// Emit HTTP request
String pedidosRequestEventId = 'REQ-' + pedidosCorrelationId + '-1';
IntegrationEventPublisher.emit(
  'testing-Pedidos',
  'HTTP_REQUEST',
  pedidosCorrelationId,
  null,
  '{"url":"https://api.example.com/orders","method":"POST","body":"{\\"orderId\\":\\"12345\\"}"}'
);

// Emit error response
IntegrationEventPublisher.emit(
  'testing-Pedidos',
  'HTTP_RESPONSE',
  pedidosCorrelationId,
  pedidosRequestEventId,
  '{"statusCode":500,"responseTime":200,"error":"Internal Server Error"}'
);

// Emit exception event
IntegrationEventPublisher.emit(
  'testing-Pedidos',
  'APEX_EXCEPTION',
  pedidosCorrelationId,
  null,
  '{"errorStackTrace":"Class.OrderSyncService.processOrder: line 45, column 1","rootCauseError":"HTTP 500 from external API","source":"Order API"}'
);

// Emit batch failure
IntegrationEventPublisher.emit(
  'testing-Pedidos',
  'BATCH_FAILED',
  pedidosCorrelationId,
  null,
  '{"totalProcessed":0,"success":false,"errorSummary":"External API failure"}'
);

System.debug('Pedidos integration simulation completed with error');

// Integration 3: Direcciones (Addresses) - Partial success
System.debug('Starting Direcciones integration simulation');

String direccionesCorrelationId =
  'CORR-DIRECCIONES-' + String.valueOf(System.currentTimeMillis());
IntegrationEventPublisher.emit(
  'testing-Direcciones',
  'BATCH_START',
  direccionesCorrelationId,
  null,
  '{"integration":"Direcciones Sync","mode":"TEST","totalExpected":10}'
);

// Multiple requests simulation
for (Integer i = 1; i <= 3; i++) {
  String dirRequestId = 'REQ-' + direccionesCorrelationId + '-' + i;
  IntegrationEventPublisher.emit(
    'testing-Direcciones',
    'HTTP_REQUEST',
    direccionesCorrelationId,
    null,
    '{"url":"https://api.example.com/addresses/' + i + '","method":"GET"}'
  );

  // Simulate mix of success and failure
  if (i < 3) {
    IntegrationEventPublisher.emit(
      'testing-Direcciones',
      'HTTP_RESPONSE',
      direccionesCorrelationId,
      dirRequestId,
      '{"statusCode":200,"responseTime":100,"address":{"id":' +
        i +
        ',"street":"Main St"}}'
    );
  } else {
    IntegrationEventPublisher.emit(
      'testing-Direcciones',
      'HTTP_RESPONSE',
      direccionesCorrelationId,
      dirRequestId,
      '{"statusCode":404,"responseTime":50,"error":"Address not found"}'
    );
  }
}

IntegrationEventPublisher.emit(
  'testing-Direcciones',
  'BATCH_COMPLETE',
  direccionesCorrelationId,
  null,
  '{"totalProcessed":2,"success":true,"partialSuccess":true}'
);

System.debug('Direcciones integration simulation completed');

System.debug(
  'All integration simulations completed. Check the Integration Health Dashboard for results.'
);
