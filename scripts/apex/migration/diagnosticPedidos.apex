/**
 * Comprehensive diagnostic script for Pedidos integration
 * Checks pre-requisites and identifies missing dependencies
 */

System.debug('=== PEDIDOS INTEGRATION DIAGNOSTIC ===');
System.debug('');

// 1. Check if Accounts exist
List<Account> accounts = [SELECT Id, Clientes_ID__c FROM Account LIMIT 5];
System.debug('📋 Accounts in Salesforce: ' + [SELECT COUNT() FROM Account]);
if (!accounts.isEmpty()) {
    System.debug('   Sample Accounts:');
    for (Account acc : accounts) {
        System.debug('   - Id: ' + acc.Id + ', Clientes_ID__c: ' + acc.Clientes_ID__c);
    }
} else {
    System.debug('   ❌ NO ACCOUNTS FOUND - Sync Accounts first!');
}

System.debug('');

// 2. Check if Products exist
List<Product2> products = [SELECT Id, ProductCode, Productos_ID__c FROM Product2 LIMIT 5];
System.debug('📦 Products in Salesforce: ' + [SELECT COUNT() FROM Product2]);
if (!products.isEmpty()) {
    System.debug('   Sample Products:');
    for (Product2 prod : products) {
        System.debug('   - Id: ' + prod.Id + ', Productos_ID__c: ' + prod.Productos_ID__c + ', Code: ' + prod.ProductCode);
    }
} else {
    System.debug('   ❌ NO PRODUCTS FOUND - Sync Products first!');
}

System.debug('');

// 3. Check Pricebook
Id pbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1]?.Id;
System.debug('💰 Standard Pricebook: ' + (pbId != null ? '✅ Found (' + pbId + ')' : '❌ NOT FOUND'));

if (pbId != null) {
    Integer pbeCount = [SELECT COUNT() FROM PricebookEntry WHERE Pricebook2Id = :pbId];
    System.debug('   PricebookEntries in Standard Pricebook: ' + pbeCount);
}

System.debug('');

// 4. Check Orders created
Integer orderCount = [SELECT COUNT() FROM Order];
System.debug('📄 Orders in Salesforce: ' + orderCount);

// 5. Check Integration Logs
Integer logCount = [SELECT COUNT() FROM Integration_Log__c WHERE Context__c LIKE '%Pedidos%'];
System.debug('📊 Integration Logs for Pedidos: ' + logCount);

if (logCount > 0) {
    List<Integration_Log__c> recentLogs = [
        SELECT Id, Context__c, Message__c, Status__c, CreatedDate
        FROM Integration_Log__c
        WHERE Context__c LIKE '%Pedidos%'
        ORDER BY CreatedDate DESC
        LIMIT 5
    ];
    System.debug('   Recent Logs:');
    for (Integration_Log__c log : recentLogs) {
        System.debug('   - [' + log.Status__c + '] ' + log.Context__c);
        System.debug('     → ' + log.Message__c.abbreviate(100));
    }
}

System.debug('');
System.debug('=== RECOMMENDATIONS ===');
if (accounts.isEmpty()) {
    System.debug('1️⃣  Run: Sync Accounts from SAP B1 first (DireccionesIntegrationJob)');
}
if (products.isEmpty()) {
    System.debug('2️⃣  Run: Sync Products from SAP B1 (ProductosIntegrationJob)');
}
if (pbId == null) {
    System.debug('3️⃣  Create Standard Pricebook in Salesforce');
}
System.debug('');
System.debug('=== END DIAGNOSTIC ===');
