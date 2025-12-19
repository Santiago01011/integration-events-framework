
// Anonymous Apex script to insert sample Integration_Log__c records for local testing.
// Run with:
//   sfdx force:apex:execute -f scripts/apex/testIntegrationLogs.apex -u <ORG_ALIAS>

List<Integration_Log__c> sampleLogs = new List<Integration_Log__c>();

Long ts = Datetime.now().getTime();

sampleLogs.add(new Integration_Log__c(
	Context__c = 'Pedidos',
	Normalized_Context__c = 'Pedidos',
	Message__c = 'Automated test log - created for integration health dashboard',
	PayloadId__c = 'PAYLOAD_TEST_001_' + String.valueOf(ts),
	JobId__c = 'JOB_TEST_001',
	Processed__c = false,
	Source__c = 'UnitTestScript'
));

sampleLogs.add(new Integration_Log__c(
	Context__c = 'Pedidos',
	Normalized_Context__c = 'Pedidos',
	Message__c = 'Second automated test log (processed)',
	PayloadId__c = 'PAYLOAD_TEST_002_' + String.valueOf(ts),
	JobId__c = 'JOB_TEST_002',
	Processed__c = true,
	Source__c = 'UnitTestScript'
));

sampleLogs.add(new Integration_Log__c(
	Context__c = 'Productos',
	Normalized_Context__c = 'Productos',
	Message__c = 'Producto test log',
	PayloadId__c = 'PAYLOAD_TEST_003_' + String.valueOf(ts),
	JobId__c = 'JOB_TEST_003',
	Processed__c = false,
	Source__c = 'UnitTestScript'
));

sampleLogs.add(new Integration_Log__c(
	Context__c = 'Pedidos_Batch',
	Normalized_Context__c = 'Pedidos',
	Message__c = 'Batch-style test log',
	PayloadId__c = 'PAYLOAD_TEST_004_' + String.valueOf(ts),
	JobId__c = 'JOB_TEST_004',
	Processed__c = false,
	Source__c = 'UnitTestScript'
));

insert sampleLogs;

System.debug('Inserted ' + sampleLogs.size() + ' Integration_Log__c records.');

// Quick verification counts
Integer total = [SELECT count() FROM Integration_Log__c];
Integer unprocessed = [SELECT count() FROM Integration_Log__c WHERE Processed__c = false];
System.debug('Integration_Log__c totals -> total: ' + total + ', unprocessed: ' + unprocessed);

// Return the inserted records' Ids in the anonymous script output
for (Integration_Log__c rec : sampleLogs) {
	System.debug('Inserted Log Id: ' + rec.Id + ' PayloadId: ' + rec.PayloadId__c);
}
