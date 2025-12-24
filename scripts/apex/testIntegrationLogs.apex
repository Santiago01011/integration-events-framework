
// Anonymous Apex script to insert sample Integration_Log__c records for local testing.
// Run with:
//   sfdx force:apex:execute -f scripts/apex/testIntegrationLogs.apex -u <ORG_ALIAS>

List<Map<String, Object>> eventPayloads = new List<Map<String, Object>>{
	new Map<String, Object>{
		'integrationCode' => 'HTTP-ORDERS',
		'observationType' => 'REQUEST_DISPATCHED',
		'correlationId' => 'CORR-1001',
		'parentEventId' => 'EVT-1000',
		'context' => 'Pedidos.OrderCreation - Automated test log for OrderCreation'
	},
	new Map<String, Object>{
		'integrationCode' => 'HTTP-ORDERS',
		'observationType' => 'RESPONSE_RECEIVED',
		'correlationId' => 'CORR-1001',
		'parentEventId' => 'EVT-1001',
		'context' => 'Pedidos.Payment - Payment response observed from gateway'
	},
	new Map<String, Object>{
		'integrationCode' => 'INVENTORY-SYNC',
		'observationType' => 'REQUEST_DISPATCHED',
		'correlationId' => 'CORR-2002',
		'context' => 'Productos.InventorySync - Inventory sync request emitted'
	},
	new Map<String, Object>{
		'integrationCode' => 'BATCH-BILLING',
		'observationType' => 'JOB_STARTED',
		'correlationId' => 'CORR-3003',
		'context' => 'Facturas.Batch - Billing job kicked off for today\'s batch'
	}
};

Integer published = 0;

for (Map<String, Object> payload : eventPayloads) {
	IntegrationEventPublisher.emit(
		(String) payload.get('integrationCode'),
		(String) payload.get('observationType'),
		(String) payload.get('correlationId'),
		(String) payload.get('parentEventId'),
		(String) payload.get('context')
	);
	published++;
}

List<Integration_Log__c> logs = [
	SELECT Id, IntegrationCode__c, ObservationType__c, CorrelationId__c, Context__c, Normalized_Context__c, OccurredAt__c
	FROM Integration_Log__c
	ORDER BY OccurredAt__c DESC
	LIMIT :published
];

System.debug('Published ' + published + ' canonical events.');

for (Integration_Log__c rec : logs) {
	System.debug('Log ' + rec.Id + ' / ' + rec.IntegrationCode__c + ' / ' + rec.ObservationType__c + ' / ' + rec.Normalized_Context__c + ' / ' + rec.Context__c);
}
