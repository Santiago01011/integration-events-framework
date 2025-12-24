// Script to import legacy logs into the new data model
// Run with: sf apex run -f scripts/apex/migration/importLegacyLogs.apex

List<Map<String, Object>> legacyLogs = new List<Map<String, Object>>{
    new Map<String, Object>{
        'Message__c' => 'FAILED - Contacts Integration\nDatabase: CMK | Mode: LIVE\n\nROOT_CAUSE: Exception in execute: SAP B1 Authentication failed: <!DOCTYPE html>',
        'StackTrace__c' => 'Class.IntegrationService.execute: line 45, column 1',
        'JobId__c' => '707000000000001',
        'Context__c' => 'Contacts Sync'
    },
    new Map<String, Object>{
        'Message__c' => 'Success - Orders Integration\nOrder #12345 created successfully in SAP.',
        'StackTrace__c' => '',
        'JobId__c' => '707000000000002',
        'Context__c' => 'Orders Sync'
    },
    new Map<String, Object>{
        'Message__c' => 'Warning - Inventory Sync\nSKU 999 not found in source system.',
        'StackTrace__c' => '',
        'JobId__c' => '707000000000003',
        'Context__c' => 'Inventory Sync'
    }
};

for (Map<String, Object> legacyLog : legacyLogs) {
    String message = (String) legacyLog.get('Message__c');
    String stackTrace = (String) legacyLog.get('StackTrace__c');
    String jobId = (String) legacyLog.get('JobId__c');
    String legacyContext = (String) legacyLog.get('Context__c');

    // 1. Infer Integration Code and Observation Type
    String integrationCode = 'LEGACY_MIGRATION';
    String observationType = 'INFO';

    if (message.containsIgnoreCase('Contacts')) {
        integrationCode = 'SAP_CONTACTS';
    } else if (message.containsIgnoreCase('Orders')) {
        integrationCode = 'SAP_ORDERS';
    } else if (message.containsIgnoreCase('Inventory')) {
        integrationCode = 'SAP_INVENTORY';
    }

    if (message.containsIgnoreCase('FAILED') || message.containsIgnoreCase('Exception')) {
        observationType = 'EXCEPTION_THROWN';
    } else if (message.containsIgnoreCase('Success')) {
        observationType = 'JOB_COMPLETED';
    } else if (message.containsIgnoreCase('Warning')) {
        observationType = 'WARNING_LOGGED';
    }

    // 2. Construct the new JSON Context
    Map<String, Object> newContext = new Map<String, Object>{
        'legacyMessage' => message,
        'legacyStackTrace' => stackTrace,
        'legacyJobId' => jobId,
        'legacyContext' => legacyContext,
        'migrationNote' => 'Imported from legacy CSV'
    };

    // 3. Emit the event (which will trigger the handler to normalize and save)
    IntegrationEventPublisher.emit(
        integrationCode,
        observationType,
        UUID.randomUUID().toString(), // Generate a new Correlation ID
        null,
        JSON.serialize(newContext)
    );
}

System.debug('Imported ' + legacyLogs.size() + ' legacy logs into the new data model.');
