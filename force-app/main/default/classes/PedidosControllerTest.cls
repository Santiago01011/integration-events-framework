@IsTest
public with sharing class PedidosControllerTest {
    /**
     * @description Obtiene o crea la lista de precios estándar en contexto de test.
     * En test context, debemos obtener el pricebook estándar con Test.getStandardPricebookId()
     * @return Id del Pricebook2 estándar.
     */
    private static Id getStandardPricebookId() {
        return Test.getStandardPricebookId();
    }

    /**
     * @description Crea un PricebookEntry para el producto indicado.
     * @param productId Id del producto.
     * @param unitPrice Precio unitario a asignar.
     * @return Id del PricebookEntry activo asociado.
     */
    private static Id createPricebookEntry(Id productId, Decimal unitPrice) {
        Id stdPbId = getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId, 
            Product2Id = productId, 
            UnitPrice = unitPrice, 
            IsActive = true
        );
        insert pbe;
        return pbe.Id;
    }

    /**
     * @description Crea un Account y un Product2 mínimos para las pruebas, con IDs externos esperados.
     * @return Mapa con claves 'acc' y 'prod' para los Ids creados.
     */
    private static Map<String, Id> seedCoreData() {
        Account acc = new Account(Name = 'Cuenta Test', Clientes_ID__c = 'ACC-001');
        insert acc;
        Product2 prod = new Product2(Name = 'Producto Test', Productos_ID__c = 'PROD-001', IsActive = true);
        insert prod;
        createPricebookEntry(prod.Id, 100);
        return new Map<String, Id>{ 'acc' => acc.Id, 'prod' => prod.Id };
    }

    /**
     * @description Construye un payload JSON mínimo válido para un pedido con una o más líneas.
    * @param docEntry DocEntry del pedido.
    * @param cardCode CardCode (Clientes_ID__c) de la cuenta.
    * @param itemCode ItemCode (Productos_ID__c) del producto.
    * @param lineNums Números de línea a incluir.
    * @return Cadena JSON lista para procesar.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static String buildPayload(String docEntry, String cardCode, String itemCode, List<Integer> lineNums) {
        List<String> values = new List<String>();
        for (Integer ln : lineNums) {
            values.add('{"Orders":{' +
                '"DocEntry":' + docEntry + ',' +
                '"DocNum":123,' +
                '"DocType":"I",' +
                '"DocDate":"2025-09-20",' +
                '"DocDueDate":"2025-09-21",' +
                '"CardCode":"' + cardCode + '",' +
                '"Address":"Dir X",' +
                '"DocTotal":1000,' +
                '"DocCurrency":"CLP",' +
                '"DocumentStatus":"A"' +
                '},' +
                '"Orders/DocumentLines":{' +
                '"LineNum":' + ln + ',' +
                '"ItemCode":"' + itemCode + '",' +
                '"Quantity":2,' +
                '"Price":100,' +
                '"PriceAfterVAT":119,' +
                '"TaxCode":"IVA"' +
                '}}');
        }
        return '{"value":[' + String.join(values, ',') + ']}';
    }

    @IsTest
    static void testHappyPathUnaOrdenDosLineas() {
        // Setup: Create test data
        seedCoreData();
        String payload = buildPayload('1001', 'ACC-001', 'PROD-001', new List<Integer>{0,1});
        
        Test.startTest();
        PedidosController.processOrdersData(payload);
        Test.stopTest();

        // Verify: Order created with correct lookups
        List<Order> ordenes = [SELECT Id, Pedidos_ID__c, AccountId, Pricebook2Id, Status, 
                                      Codigo_socio_de_negocios__c, Nombre_socio_de_negocios__c,
                                      RUT_del_socio_de_negocios__c, Fecha_contabilizaci_n__c,
                                      Hora_contabilizaci_n__c
                               FROM Order WHERE Pedidos_ID__c = '1001'];
        System.assertEquals(1, ordenes.size(), 'Debe crear/actualizar 1 pedido');
        System.assertNotEquals(null, ordenes[0].AccountId, 'Debe resolver Account');
        System.assertNotEquals(null, ordenes[0].Pricebook2Id, 'Debe asignar Pricebook');
        System.assertEquals('Borrador', ordenes[0].Status, 'Status debe ser Borrador');
        
        // Verify: Business partner lookup fields populated
        System.assertNotEquals(null, ordenes[0].Codigo_socio_de_negocios__c, 'Codigo socio debe estar poblado');
        System.assertNotEquals(null, ordenes[0].Nombre_socio_de_negocios__c, 'Nombre socio debe estar poblado');
        System.assertNotEquals(null, ordenes[0].RUT_del_socio_de_negocios__c, 'RUT socio debe estar poblado');
        
        // Verify: OrderItems created with correct mappings
        List<OrderItem> lineas = [SELECT Id, Productos_de_Pedidos_ID__c, OrderId, Product2Id, 
                                         PricebookEntryId, Quantity, UnitPrice, L_nea_detalle_nota_venta__c,
                                         Cantidad_comprada__c, Precio_neto_del_producto__c
                                  FROM OrderItem WHERE OrderId = :ordenes[0].Id 
                                  ORDER BY L_nea_detalle_nota_venta__c];
        System.assertEquals(2, lineas.size(), 'Debe crear 2 líneas');
        
        for (Integer i = 0; i < lineas.size(); i++) {
            OrderItem li = lineas[i];
            System.assertNotEquals(null, li.Product2Id, 'Línea ' + i + ' debe resolver Product2');
            System.assertNotEquals(null, li.PricebookEntryId, 'Línea ' + i + ' debe resolver PBE');
            System.assertEquals(2, li.Quantity.intValue(), 'Línea ' + i + ' cantidad mapeada');
            System.assertEquals(100, li.UnitPrice.intValue(), 'Línea ' + i + ' precio mapeado');
            System.assertEquals(String.valueOf(i), li.L_nea_detalle_nota_venta__c, 'LineNum debe coincidir');
        }
    }

    @IsTest
    static void testOmisionPorCuentaYProductoFaltantes() {
        // Setup: No crear Account/Product2 para forzar omisiones
        String payload = buildPayload('2001', 'INEXISTENTE', 'PROD-NO', new List<Integer>{0});
        
        Test.startTest();
        PedidosController.processOrdersData(payload);
        Test.stopTest();
        
        // Verify: Order and OrderItems should be omitted due to missing lookups
        System.assertEquals(0, [SELECT count() FROM Order WHERE Pedidos_ID__c = '2001'], 
                          'Debe omitir el pedido cuando no existe Account');
        System.assertEquals(0, [SELECT count() FROM OrderItem WHERE Productos_de_Pedidos_ID__c LIKE '2001-%'], 
                          'No debe crear líneas cuando no existe Product/Account');
    }

    @IsTest
    static void testPayloadVacio() {
        // Setup: Empty payload
        String payload = '{"value":[]}';
        
        Test.startTest();
        PedidosController.processOrdersData(payload);
        Test.stopTest();
        
        // Verify: No orders created
        System.assertEquals(0, [SELECT count() FROM Order], 
                          'No debe crear pedidos con payload vacío');
    }

    @IsTest
    static void testUpsertOrdenExistente() {
        // Setup: Create initial order
        seedCoreData();
        String payload1 = buildPayload('4001', 'ACC-001', 'PROD-001', new List<Integer>{0});
        PedidosController.processOrdersData(payload1);
        
        Order orderBefore = [SELECT Id, Total_documento_con_IVA__c FROM Order WHERE Pedidos_ID__c = '4001'];
        System.assertNotEquals(null, orderBefore.Id, 'Orden debe existir antes de actualización');
        
        // Act: Update same order with different total
        Test.startTest();
        String payload2 = '{"value":[{"Orders":{' +
            '"DocEntry":4001,' +
            '"DocNum":123,' +
            '"DocType":"I",' +
            '"DocDate":"2025-09-20",' +
            '"DocDueDate":"2025-09-21",' +
            '"CardCode":"ACC-001",' +
            '"Address":"Dir X",' +
            '"DocTotal":2500,' +  // Changed from 1000 to 2500
            '"DocCurrency":"CLP",' +
            '"DocumentStatus":"A"' +
            '},' +
            '"Orders/DocumentLines":{' +
            '"LineNum":0,' +
            '"ItemCode":"PROD-001",' +
            '"Quantity":5,' +  // Changed from 2 to 5
            '"Price":100,' +
            '"PriceAfterVAT":119,' +
            '"TaxCode":"IVA"' +
            '}}]}';
        PedidosController.processOrdersData(payload2);
        Test.stopTest();
        
        // Verify: Order updated, not duplicated
        List<Order> orders = [SELECT Id, Total_documento_con_IVA__c FROM Order WHERE Pedidos_ID__c = '4001'];
        System.assertEquals(1, orders.size(), 'Debe seguir habiendo solo 1 orden');
        System.assertEquals(orderBefore.Id, orders[0].Id, 'Debe ser la misma orden (upsert)');
        System.assertEquals(2500, orders[0].Total_documento_con_IVA__c.intValue(), 'Total debe actualizarse');
        
        // Verify: OrderItem quantity updated
        OrderItem line = [SELECT Quantity FROM OrderItem WHERE Productos_de_Pedidos_ID__c = '4001-0'];
        System.assertEquals(5, line.Quantity.intValue(), 'Cantidad debe actualizarse');
    }

    @IsTest
    static void testPayloadInvalido() {
        // Setup: Invalid JSON
        String payload = '{invalid json}';
        
        Test.startTest();
        PedidosController.processOrdersData(payload);
        Test.stopTest();
        
        // Verify: No crash, no orders created (graceful handling)
        System.assertEquals(0, [SELECT count() FROM Order], 
                          'No debe crear pedidos con JSON inválido');
    }
}