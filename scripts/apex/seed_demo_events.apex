List<IEF_EventRequest> requests = new List<IEF_EventRequest>();

// 1. SAP Order Sync (Success)
requests.add(new IEF_EventRequest(
    'SAP_ECC',
    'ORDER_SYNC_DISPATCHED',
    'SAP-ORD-984321',
    null,
    '{"orderId": "984321", "customer": "Acme Corp", "total": 14250.00, "currency": "USD"}'
));

// 2. Stripe Webhook (Payment Captured)
requests.add(new IEF_EventRequest(
    'STRIPE_PAYMENTS',
    'PAYMENT_INTENT_SUCCEEDED',
    'ch_3Mtw12LkdIwHu7ix',
    null,
    '{"amount": 4999, "currency": "usd", "status": "succeeded", "customer": "cus_N5xL8k"}'
));

// 3. Salesforce Marketing Cloud Sync (In Progress)
requests.add(new IEF_EventRequest(
    'SFMC_CONTACTS',
    'SUBSCRIBER_SYNC',
    'MC-SUB-10029',
    null,
    '{"subscriberKey": "003O300000abc123", "email": "john.doe@example.com", "status": "Active"}'
));

// 4. NetSuite Invoice Generation (Warning / Retry)
requests.add(new IEF_EventRequest(
    'NETSUITE_ERP',
    'INVOICE_CREATE_TIMEOUT',
    'NS-INV-44021',
    null,
    '{"invoiceId": "INV-44021", "retryAttempt": 1, "endpoint": "https://api.netsuite.com/rest/invoice"}'
));

// 5. Legacy Warehouse DB (Fatal Error / Dead Letter)
requests.add(new IEF_EventRequest(
    'LEGACY_WMS',
    'INVENTORY_LOCK_FAILURE',
    'WMS-LOCK-8812',
    null,
    '{"sku": "SKU-9902", "warehouse": "WH-EAST", "errorCode": "ORA-00054"}'
));

// Emit bulk
IntegrationEventPublisher.emit(requests);
System.debug('Published ' + requests.size() + ' integration events to EventBus.');
