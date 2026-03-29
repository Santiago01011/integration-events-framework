Datetime now = Datetime.now();

List<Integration_Log__c> logs = new List<Integration_Log__c>{
    // WARN: Partial responses
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-INV',
        ObservationType__c = 'PARTIAL_RESPONSE',
        Normalized_Context__c = 'Inventario',
        CorrelationId__c = 'CORR-101',
        OccurredAt__c = now.addMinutes(-25),
        Context__c = '{"sync":"inventory","warehouse":"MX-02","total":500,"received":420,"missing":80}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-INV',
        ObservationType__c = 'PARTIAL_RESPONSE',
        Normalized_Context__c = 'Inventario',
        CorrelationId__c = 'CORR-102',
        OccurredAt__c = now.addMinutes(-18),
        Context__c = '{"sync":"inventory","warehouse":"MX-01","total":300,"received":285,"missing":15}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PED',
        ObservationType__c = 'PARTIAL_RESPONSE',
        Normalized_Context__c = 'Pedidos',
        CorrelationId__c = 'CORR-103',
        OccurredAt__c = now.addMinutes(-12),
        Context__c = '{"orderId":"ORD-1004","status":206,"itemsExpected":10,"itemsReceived":7}'
    ),
    // WARN: Retry attempts
    new Integration_Log__c(
        IntegrationCode__c = 'HTTP-PROD',
        ObservationType__c = 'RETRY_ATTEMPT',
        Normalized_Context__c = 'Productos',
        CorrelationId__c = 'CORR-104',
        OccurredAt__c = now.addMinutes(-15),
        Context__c = '{"sku":"PROD-ABC","attempt":2,"maxRetries":3,"reason":"timeout"}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'SAP-INV',
        ObservationType__c = 'RETRY_ATTEMPT',
        Normalized_Context__c = 'Facturas',
        CorrelationId__c = 'CORR-105',
        OccurredAt__c = now.addMinutes(-8),
        Context__c = '{"batchId":"B-101","attempt":1,"maxRetries":3,"reason":"RFC unavailable"}'
    ),
    // INFO: DML operations
    new Integration_Log__c(
        IntegrationCode__c = 'SYS-AUDIT',
        ObservationType__c = 'DML_INSERT',
        Normalized_Context__c = 'Auditoria',
        CorrelationId__c = 'CORR-106',
        OccurredAt__c = now.addMinutes(-30),
        Context__c = '{"object":"Integration_Log__c","recordsInserted":14,"trigger":"Apex"}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'SYS-AUDIT',
        ObservationType__c = 'DML_INSERT',
        Normalized_Context__c = 'Auditoria',
        CorrelationId__c = 'CORR-107',
        OccurredAt__c = now.addMinutes(-20),
        Context__c = '{"object":"Integration_Log__c","recordsInserted":6,"trigger":"Apex"}'
    ),
    new Integration_Log__c(
        IntegrationCode__c = 'SYS-AUDIT',
        ObservationType__c = 'DML_INSERT',
        Normalized_Context__c = 'Auditoria',
        CorrelationId__c = 'CORR-108',
        OccurredAt__c = now.addMinutes(-10),
        Context__c = '{"object":"Integration_Log__c","recordsInserted":8,"trigger":"Apex"}'
    )
};

insert logs;
System.debug('Inserted ' + logs.size() + ' WARN/INFO severity logs');
