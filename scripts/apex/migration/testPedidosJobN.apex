/**
 * Test script to enqueue PedidosIntegrationJob with N orders for load testing
 * and error handling validation.
 * 
 * Generates a payload with multiple orders and order items to test:
 * - Batch processing with pagination
 * - Error accumulation via IntegrationEventPublisher
 * - Bulk upsert handling
 */

Integer N = 5; // Number of orders to generate

List<Object> vals = new List<Object>();
for (Integer i = 1; i <= N; i++) {
    Map<String, Object> orderNode = new Map<String, Object>{
        'Orders' => new Map<String, Object>{
            'DocEntry' => 300000 + i,
            'DocNum' => 240000 + i,
            'DocType' => 'I',
            'DocDate' => '2025-09-' + String.valueOf(i).leftPad(2, '0'),
            'DocTime' => '10:00:00',
            'DocDueDate' => '2025-09-' + String.valueOf(i + 1).leftPad(2, '0'),
            'CardCode' => '001dx00000TestAccount' + i,
            'CardName' => 'Test Account ' + i,
            'Address' => 'Test Address ' + i,
            'Address2' => 'Test Address 2 ' + i,
            'NumAtCard' => null,
            'DocTotal' => 1000000.0 * i,
            'DocCurrency' => 'CLP',
            'SalesPersonCode' => 100 + i,
            'Comments' => 'Test order ' + i,
            'ShipToCode' => 'TEST' + i,
            'U_RUTA' => 'RUTA-' + i,
            'U_RECETA' => 'N',
            'U_SEI_IDW' => 'B2B-TEST-' + i
        },
        'Orders/DocumentLines' => new Map<String, Object>{
            'LineNum' => 0,
            'ItemCode' => 'TEST-ITEM-' + i,
            'Quantity' => 1.0 + i,
            'Price' => 100000.0 * i,
            'PriceAfterVAT' => 119000.0 * i,
            'BarCode' => 'BARCODE-' + i,
            'ShipDate' => '2025-09-' + String.valueOf(i).leftPad(2, '0'),
            'TaxCode' => 'IVA'
        }
    };
    vals.add(orderNode);
}

Map<String, Object> root = new Map<String, Object>{ 'value' => vals };
String payload = JSON.serialize(root);

// Enqueue job with mock payload
String baseURL = 'https://cmk.cloudseidor.com:50000/b1s/v1';
String database = Label.BBDD_PROFAR;
String username = Label.USUARIO_INT;
String password = Label.PASS_PROFAR;

PedidosIntegrationJob job = new PedidosIntegrationJob(baseURL, database, username, password, payload);
Id qid = System.enqueueJob(job);
System.debug('✅ Enqueued PedidosIntegrationJob id=' + qid);
System.debug('   Load test with N=' + N + ' orders');
System.debug('   This will enqueue PedidosBatchJob for processing');
