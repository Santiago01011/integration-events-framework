List<IEF_EventRequest> requests = new List<IEF_EventRequest>();

// 1. SAP Order Sync (Success)
requests.add(new IEF_EventRequest(
    'SAP_ECC',
    'ORDER_SYNC_DISPATCHED',
    'SAP-ORD-984321',
    '{"orderId": "984321", "customer": "Acme Corp", "total": 14250.00, "currency": "USD"}',
    'Order successfully emitted to SAP ECC Gateway'
));

// 2. Stripe Webhook (Payment Captured)
requests.add(new IEF_EventRequest(
    'STRIPE_PAYMENTS',
    'PAYMENT_INTENT_SUCCEEDED',
    'ch_3Mtw12LkdIwHu7ix',
    '{"amount": 4999, "currency": "usd", "status": "succeeded", "customer": "cus_N5xL8k"}',
    'Stripe webhook payload captured'
));

// 3. Salesforce Marketing Cloud Sync (In Progress)
requests.add(new IEF_EventRequest(
    'SFMC_CONTACTS',
    'SUBSCRIBER_SYNC',
    'MC-SUB-10029',
    '{"subscriberKey": "003O300000abc123", "email": "john.doe@example.com", "status": "Active"}',
    'Subscriber batch sync dispatched'
));

// 4. NetSuite Invoice Generation (Warning / Retry)
requests.add(new IEF_EventRequest(
    'NETSUITE_ERP',
    'INVOICE_CREATE_TIMEOUT',
    'NS-INV-44021',
    '{"invoiceId": "INV-44021", "retryAttempt": 1, "endpoint": "https://api.netsuite.com/rest/invoice"}',
    'Gateway timeout 504 received from NetSuite API; retry queued'
));

// 5. Legacy Warehouse DB (Fatal Error / Dead Letter)
requests.add(new IEF_EventRequest(
    'LEGACY_WMS',
    'INVENTORY_LOCK_FAILURE',
    'WMS-LOCK-8812',
    '{"sku": "SKU-9902", "warehouse": "WH-EAST", "errorCode": "ORA-00054"}',
    'Fatal deadlock exception in warehouse DB connector: resource busy and acquire with NOWAIT specified'
));

// Emit bulk
IntegrationEventPublisher.emit(requests);
System.debug('Published ' + requests.size() + ' integration events to EventBus.');
