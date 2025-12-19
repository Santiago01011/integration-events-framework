/**
 * Script to check the results of PedidosBatchJob execution
 * Shows created orders, errors logged, and integration status
 */

System.debug('=== PEDIDOS BATCH JOB RESULTS ===');

// Check created Orders
List<Order> createdOrders = [
    SELECT Id, Pedidos_ID__c, N_mero_de_la_nota_de_ventas__c, Total_documento_con_IVA__c, Status
    FROM Order
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('Created Orders: ' + createdOrders.size());
for (Order ord : createdOrders) {
    System.debug('  - DocEntry: ' + ord.Pedidos_ID__c + ', DocNum: ' + ord.N_mero_de_la_nota_de_ventas__c + ', Total: ' + ord.Total_documento_con_IVA__c + ', Status: ' + ord.Status);
}

// Check created OrderItems
List<OrderItem> createdItems = [
    SELECT Id, Order.Pedidos_ID__c, L_nea_detalle_nota_venta__c, Quantity, UnitPrice
    FROM OrderItem
    ORDER BY CreatedDate DESC
    LIMIT 20
];

System.debug('Created OrderItems: ' + createdItems.size());
for (OrderItem item : createdItems) {
    System.debug('  - OrderId: ' + item.Order.Pedidos_ID__c + ', Line: ' + item.L_nea_detalle_nota_venta__c + ', Qty: ' + item.Quantity + ', Price: ' + item.UnitPrice);
}

// Check Integration Errors - ALL contexts
List<Integration_Log__c> allErrorLogs = [
    SELECT Id, Context__c, Message__c, Status__c, CreatedDate
    FROM Integration_Log__c
    WHERE Context__c LIKE '%Pedidos%'
    ORDER BY CreatedDate DESC
    LIMIT 50
];

System.debug('⚠️  ALL Integration Error Logs: ' + allErrorLogs.size());
if (allErrorLogs.isEmpty()) {
    System.debug('  → No errors logged (all orders processed successfully)');
} else {
    for (Integration_Log__c log : allErrorLogs) {
        System.debug('  - Context: ' + log.Context__c);
        System.debug('    Status: ' + log.Status__c);
        System.debug('    Message: ' + log.Message__c);
        System.debug('    Created: ' + log.CreatedDate);
        System.debug('    ---');
    }
}

// Summary
System.debug('');
System.debug('=== SUMMARY ===');
System.debug('Total Orders Created: ' + createdOrders.size());
System.debug('Total OrderItems Created: ' + createdItems.size());
System.debug('Total Error Logs: ' + allErrorLogs.size());
System.debug('');
System.debug('⚡ TIP: If Orders/Items = 0 and Error Logs > 0, check messages for:');
System.debug('  1. Missing Account (CardCode not found in Salesforce)');
System.debug('  2. Missing Product2 (ItemCode not found in Salesforce)');
System.debug('  3. Missing PricebookEntry (Product not in active Pricebook)');
System.debug('');
System.debug('=== END RESULTS ===');
