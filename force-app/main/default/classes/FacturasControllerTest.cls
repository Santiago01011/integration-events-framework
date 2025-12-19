@IsTest
public with sharing class FacturasControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create common test data used by most tests
        Account acc = new Account(Name = 'Cuenta Test', Clientes_ID__c = 'ACC-001');
        insert acc;
        Product2 prod = new Product2(Name = 'Producto Test', Productos_ID__c = 'PROD-001', IsActive = true);
        insert prod;
    }

    /**
     * @description Construye un payload JSON mínimo válido para una factura con una o más líneas.
     * @param docEntry DocEntry de la factura.
     * @param cardCode CardCode (Clientes_ID__c) de la cuenta.
     * @param itemCode ItemCode (Productos_ID__c) del producto.
     * @param lineNums Números de línea a incluir.
     * @return Cadena JSON lista para procesar.
     */
    @SuppressWarnings('PMD.ExcessiveParameterList')
    private static String buildPayload(String docEntry, String cardCode, String itemCode, List<Integer> lineNums) {
        List<String> values = new List<String>();
        for (Integer ln : lineNums) {
            values.add('{"Invoices":{' +
                '"DocEntry":' + docEntry + ',' +
                '"DocNum":123,' +
                '"DocType":"I",' +
                '"DocDate":"2025-09-20",' +
                '"DocDueDate":"2025-09-21",' +
                '"DocCurrency":"CLP",' +
                '"DocTotal":1000,' +
                '"CardCode":"' + cardCode + '",' +
                '"Address":"Dir X",' +
                '"U_SEI_FEBOSID":"FEB-001",' +
                '"U_RUTA":"RUTA-1",' +
                '"U_Receta":"N"' +
                '},' +
                '"Invoices/DocumentLines":{' +
                '"LineNum":' + ln + ',' +
                '"ItemCode":"' + itemCode + '",' +
                '"ItemDescription":"Producto Test",' +
                '"Quantity":2,' +
                '"Price":100,' +
                '"PriceAfterVAT":119,' +
                '"TaxCode":"IVA",' +
                '"WarehouseCode":"WH-001",' +
                '"BarCode":"123456789"' +
                '}}');
        }
        return '{"value":[' + String.join(values, ',') + ']}';
    }

    @IsTest
    static void testHappyPathUnaFacturaDosLineas() {
        String payload = buildPayload('1001', 'ACC-001', 'PROD-001', new List<Integer>{0,1});

        Test.startTest();
        FacturasController.processInvoicesData(payload);
        Test.stopTest();

        // Verify: Invoice created with correct lookups
        List<Facturas__c> facturas = [SELECT Id, Facturas_ID__c, Codigo_socio_de_negocios__c,
                                            Nombre_socio_de_negocios__c, RUT_del_socio_de_negocios__c,
                                            Fecha_contabilizaci_n__c, Tipo_de_documentos__c
                                     FROM Facturas__c WHERE Facturas_ID__c = '1001'];
        System.assertEquals(1, facturas.size(), 'Debe crear/actualizar 1 factura');
        System.assertNotEquals(null, facturas[0].Codigo_socio_de_negocios__c, 'Debe resolver Account');
        System.assertNotEquals(null, facturas[0].Nombre_socio_de_negocios__c, 'Debe resolver Account');
        System.assertNotEquals(null, facturas[0].RUT_del_socio_de_negocios__c, 'Debe resolver Account');

        // Verify: Invoice lines created with correct mappings
        List<Detalle_de_Facturas__c> lineas = [SELECT Id, Detalle_Facturas_ID__c, Numero_factura__c,
                                                     Producto__c, Cantidad__c, Precio__c, Precio_VAT__c,
                                                     Correlativo_interno_SAP__c
                                              FROM Detalle_de_Facturas__c WHERE Numero_factura__c = :facturas[0].Id
                                              ORDER BY Correlativo_interno_SAP__c];
        System.assertEquals(2, lineas.size(), 'Debe crear 2 líneas');

        for (Integer i = 0; i < lineas.size(); i++) {
            Detalle_de_Facturas__c li = lineas[i];
            System.assertNotEquals(null, li.Producto__c, 'Línea ' + i + ' debe resolver Product2');
            System.assertEquals(2, li.Cantidad__c, 'Línea ' + i + ' cantidad mapeada');
            System.assertEquals(100, li.Precio__c, 'Línea ' + i + ' precio mapeado');
            System.assertEquals(119, li.Precio_VAT__c, 'Línea ' + i + ' precio VAT mapeado');
            System.assertEquals(String.valueOf(i), li.Correlativo_interno_SAP__c, 'LineNum debe coincidir');
        }
    }

    @IsTest
    static void testOmisionPorCuentaFaltante() {
        // Remove the Account created by @TestSetup to test missing Account scenario
        delete [SELECT Id FROM Account WHERE Clientes_ID__c = 'ACC-001'];
        
        String payload = buildPayload('2001', 'INEXISTENTE', 'PROD-001', new List<Integer>{0});

        Test.startTest();
        FacturasController.processInvoicesData(payload);
        Test.stopTest();

        // Verify: Invoice should be omitted due to missing Account
        System.assertEquals(0, [SELECT count() FROM Facturas__c WHERE Facturas_ID__c = '2001'],
                          'Debe omitir la factura cuando no existe Account');
        System.assertEquals(0, [SELECT count() FROM Detalle_de_Facturas__c WHERE Detalle_Facturas_ID__c LIKE '2001-%'],
                          'No debe crear líneas cuando no existe Account');
    }

    @IsTest
    static void testOmisionPorProductoFaltante() {
        // Remove the Product2 created by @TestSetup to test missing Product scenario
        delete [SELECT Id FROM Product2 WHERE Productos_ID__c = 'PROD-001'];
        
        String payload = buildPayload('3001', 'ACC-001', 'PROD-INEXISTENTE', new List<Integer>{0});

        Test.startTest();
        FacturasController.processInvoicesData(payload);
        Test.stopTest();

        // Verify: Invoice created but lines omitted due to missing Product
        List<Facturas__c> facturas = [SELECT Id FROM Facturas__c WHERE Facturas_ID__c = '3001'];
        System.assertEquals(1, facturas.size(), 'Debe crear la factura cuando existe Account');

        System.assertEquals(0, [SELECT count() FROM Detalle_de_Facturas__c WHERE Numero_factura__c = :facturas[0].Id],
                          'Debe omitir líneas cuando no existe Product');
    }

    @IsTest
    static void testPayloadVacio() {
        // Setup: Empty payload
        String payload = '{"value":[]}';

        Test.startTest();
        FacturasController.processInvoicesData(payload);
        Test.stopTest();

        // Verify: No invoices created
        System.assertEquals(0, [SELECT count() FROM Facturas__c],
                          'No debe crear facturas con payload vacío');
    }

    @IsTest
    static void testPayloadInvalido() {
        String payload = 'invalid json';

        Test.startTest();
        FacturasController.processInvoicesData(payload);
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM Facturas__c],
                          'No debe crear facturas con JSON inválido');
    }

    @IsTest
    static void testUpsertFacturaExistente() {
        String payload = buildPayload('4001', 'ACC-001', 'PROD-001', new List<Integer>{0});

        Test.startTest();
        FacturasController.processInvoicesData(payload);

        List<Facturas__c> initialFacturas = [SELECT Id, Comentarios__c FROM Facturas__c WHERE Facturas_ID__c = '4001'];
        System.assertEquals(1, initialFacturas.size(), 'Debe crear factura inicial');

        // Update with modified payload
        String updatedPayload = '{"value":[{"Invoices":{"DocEntry":4001,"DocNum":123,"DocType":"I","DocDate":"2025-09-20","DocDueDate":"2025-09-21","DocCurrency":"CLP","DocTotal":2000,"CardCode":"ACC-001","Address":"Dir Updated","U_SEI_FEBOSID":"FEB-001","U_RUTA":"RUTA-1","U_Receta":"N"},"Invoices/DocumentLines":{"LineNum":0,"ItemCode":"PROD-001","ItemDescription":"Producto Test","Quantity":5,"Price":200,"PriceAfterVAT":238,"TaxCode":"IVA","WarehouseCode":"WH-001","BarCode":"123456789"}}]}';

        FacturasController.processInvoicesData(updatedPayload);
        Test.stopTest();

        // Verify: Invoice updated, not duplicated
        List<Facturas__c> updatedFacturas = [SELECT Id, Total_documento_con_IVA__c FROM Facturas__c WHERE Facturas_ID__c = '4001'];
        System.assertEquals(1, updatedFacturas.size(), 'Debe mantener una sola factura');
        System.assertEquals(2000, updatedFacturas[0].Total_documento_con_IVA__c, 'Debe actualizar el total');

        // Verify: Line updated
        List<Detalle_de_Facturas__c> lines = [SELECT Cantidad__c, Precio__c FROM Detalle_de_Facturas__c WHERE Numero_factura__c = :updatedFacturas[0].Id];
        System.assertEquals(1, lines.size(), 'Debe mantener una línea');
        System.assertEquals(5, lines[0].Cantidad__c, 'Debe actualizar cantidad');
        System.assertEquals(200, lines[0].Precio__c, 'Debe actualizar precio');
    }

    @IsTest
    static void testMultiplesFacturasMismoAccount() {
        List<String> values = new List<String>();
        values.add('{"Invoices":{"DocEntry":5001,"DocNum":123,"DocType":"I","DocDate":"2025-09-20","DocDueDate":"2025-09-21","DocCurrency":"CLP","DocTotal":1000,"CardCode":"ACC-001","Address":"Dir X","U_SEI_FEBOSID":"FEB-001","U_RUTA":"RUTA-1","U_Receta":"N"},"Invoices/DocumentLines":{"LineNum":0,"ItemCode":"PROD-001","ItemDescription":"Producto Test","Quantity":2,"Price":100,"PriceAfterVAT":119,"TaxCode":"IVA","WarehouseCode":"WH-001","BarCode":"123456789"}}');
        values.add('{"Invoices":{"DocEntry":5002,"DocNum":124,"DocType":"I","DocDate":"2025-09-21","DocDueDate":"2025-09-22","DocCurrency":"CLP","DocTotal":1500,"CardCode":"ACC-001","Address":"Dir Y","U_SEI_FEBOSID":"FEB-002","U_RUTA":"RUTA-1","U_Receta":"N"},"Invoices/DocumentLines":{"LineNum":0,"ItemCode":"PROD-001","ItemDescription":"Producto Test","Quantity":3,"Price":150,"PriceAfterVAT":178.5,"TaxCode":"IVA","WarehouseCode":"WH-001","BarCode":"123456789"}}');
        String payload = '{"value":[' + String.join(values, ',') + ']}';

        Test.startTest();
        FacturasController.processInvoicesData(payload);
        Test.stopTest();

        // Verify: Both invoices created with same Account
        List<Facturas__c> facturas = [SELECT Id, Facturas_ID__c, Codigo_socio_de_negocios__c FROM Facturas__c WHERE Facturas_ID__c IN ('5001','5002') ORDER BY Facturas_ID__c];
        System.assertEquals(2, facturas.size(), 'Debe crear 2 facturas');
        System.assertEquals(facturas[0].Codigo_socio_de_negocios__c, facturas[1].Codigo_socio_de_negocios__c, 'Ambas facturas deben resolver al mismo Account');

        // Verify: Lines created for both invoices
        System.assertEquals(1, [SELECT count() FROM Detalle_de_Facturas__c WHERE Numero_factura__c = :facturas[0].Id], 'Factura 1 debe tener línea');
        System.assertEquals(1, [SELECT count() FROM Detalle_de_Facturas__c WHERE Numero_factura__c = :facturas[1].Id], 'Factura 2 debe tener línea');
    }
}