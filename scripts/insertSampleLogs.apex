Datetime now = Datetime.now();

List<Integration_Log__c> logs = new List<Integration_Log__c>{
    // Pedidos - successful request/response pair
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PED',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Normalized_Context__c = 'Pedidos',
        CorrelationId__c = 'CORR-001',
        OccurredAt__c = now.addMinutes(-30),
        Context__c = '{"orderId":"ORD-1001","endpoint":"/api/orders","method":"POST"}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PED',
        ObservationType__c = 'RESPONSE_RECEIVED',
        Normalized_Context__c = 'Pedidos',
        CorrelationId__c = 'CORR-001',
        OccurredAt__c = now.addMinutes(-29),
        Context__c = '{"orderId":"ORD-1001","status":200,"responseTime":"1.2s"}'
    ),
    // Pedidos - failed order with error
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PED',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Normalized_Context__c = 'Pedidos',
        CorrelationId__c = 'CORR-002',
        OccurredAt__c = now.addMinutes(-25),
        Context__c = '{"orderId":"ORD-1002","endpoint":"/api/orders","method":"POST"}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PED',
        ObservationType__c = 'EXCEPTION_THROWN',
        Normalized_Context__c = 'Pedidos',
        CorrelationId__c = 'CORR-002',
        OccurredAt__c = now.addMinutes(-20),
        Context__c = '{"error":"Connection timeout","endpoint":"/api/orders","retry":3,"status":504}'
    ),
    // Pedidos - another success
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PED',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Normalized_Context__c = 'Pedidos',
        CorrelationId__c = 'CORR-005',
        OccurredAt__c = now.addMinutes(-10),
        Context__c = '{"orderId":"ORD-1003","endpoint":"/api/orders","method":"PUT"}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PED',
        ObservationType__c = 'RESPONSE_RECEIVED',
        Normalized_Context__c = 'Pedidos',
        CorrelationId__c = 'CORR-005',
        OccurredAt__c = now.addMinutes(-9),
        Context__c = '{"orderId":"ORD-1003","status":200,"responseTime":"0.8s"}'
    ),
    // Productos - sync success
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PROD',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Normalized_Context__c = 'Productos',
        CorrelationId__c = 'CORR-003',
        OccurredAt__c = now.addMinutes(-15),
        Context__c = '{"sku":"PROD-XYZ","endpoint":"/api/products/sync","method":"GET"}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PROD',
        ObservationType__c = 'RESPONSE_RECEIVED',
        Normalized_Context__c = 'Productos',
        CorrelationId__c = 'CORR-003',
        OccurredAt__c = now.addMinutes(-14),
        Context__c = '{"sku":"PROD-XYZ","status":200,"updated":true,"records":42}'
    ),
    // Productos - warning
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PROD',
        ObservationType__c = 'REQUEST_DISPATCHED',
        Normalized_Context__c = 'Productos',
        CorrelationId__c = 'CORR-006',
        OccurredAt__c = now.addMinutes(-8),
        Context__c = '{"sku":"PROD-ABC","endpoint":"/api/products/sync","method":"GET"}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PROD',
        ObservationType__c = 'PARTIAL_RESPONSE',
        Normalized_Context__c = 'Productos',
        CorrelationId__c = 'CORR-006',
        OccurredAt__c = now.addMinutes(-7),
        Context__c = '{"sku":"PROD-ABC","status":206,"partial":true,"missing":["ATTR-1","ATTR-2"]}'
    ),
    // Facturas - batch error
    new Integration_Log__c(
        IntegrationCode__c = 'SAP-INV',
        ObservationType__c = 'BATCH_ERROR',
        Normalized_Context__c = 'Facturas',
        CorrelationId__c = 'CORR-004',
        OccurredAt__c = now.addMinutes(-5),
        Context__c = '{"batchId":"B-99","failed":12,"total":100,"error":"SAP RFC connection lost"}'
    ),
    // Facturas - retry success
    new Integration_Log__c(
        IntegrationCode__c = 'SAP-INV',
        ObservationType__c = 'BATCH_PROCESSED',
        Normalized_Context__c = 'Facturas',
        CorrelationId__c = 'CORR-007',
        OccurredAt__c = now.addMinutes(-3),
        Context__c = '{"batchId":"B-100","processed":88,"total":88,"duration":"45s"}'
    ),
    // Inventario - info log
    new Integration_Log__c(
        IntegrationCode__c = 'SAP-INV-STOCK',
        ObservationType__c = 'SYNC_STARTED',
        Normalized_Context__c = 'Inventario',
        CorrelationId__c = 'CORR-008',
        OccurredAt__c = now.addMinutes(-2),
        Context__c = '{"syncType":"incremental","warehouse":"MX-01","expectedRecords":500}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'SAP-INV-STOCK',
        ObservationType__c = 'SYNC_COMPLETED',
        Normalized_Context__c = 'Inventario',
        CorrelationId__c = 'CORR-008',
        OccurredAt__c = now.addMinutes(-1),
        Context__c = '{"syncType":"incremental","warehouse":"MX-01","synced":500,"skipped":0}'
    )
};

insert logs;
System.debug('Inserted ' + logs.size() + ' sample logs');
