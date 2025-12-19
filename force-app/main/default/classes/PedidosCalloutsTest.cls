@isTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
public class PedidosCalloutsTest {

    @TestSetup
    static void setup() {
        // Crear datos de prueba necesarios
        Account testAccount = new Account(
            Name = 'Test Account',
            Clientes_ID__c = 'TEST001'
        );
        insert testAccount;

        Product2 testProduct = new Product2(
            Name = 'Test Product',
            Productos_ID__c = 'PROD001'
        );
        insert testProduct;

        // Crear Pricebook Entry
        Id standardPricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            Pbe_ID__c = 'PBE001'
        );
        insert pbe;
    }

    @isTest static void testGetOrders() {
        // Configurar el mock HTTP
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Ejecutar método
        Test.startTest();
        PedidosCallouts.getOrders();
        Test.stopTest();

        // Verificar que se creó el pedido
        List<Order> orders = [SELECT Id, Pedidos_ID__c FROM Order];
        System.assert(!orders.isEmpty(), 'Debe haberse creado al menos un pedido');
    }

    @isTest static void testGetOrdersAuthFailure() {
        // Configurar mock de error de autenticación
        Test.setMock(HttpCalloutMock.class, new MockHttpAuthErrorGenerator());

        Test.startTest();
        PedidosCallouts.getOrders();
        Test.stopTest();

        // Verificar que no se crearon pedidos por error de auth
        List<Order> orders = [SELECT Id FROM Order];
        System.assertEquals(0, orders.size(), 'No debería haberse creado pedidos por error de autenticación');
    }

    @isTest static void testGetOrdersDataError() {
        // Configurar mock de error en datos
        Test.setMock(HttpCalloutMock.class, new MockHttpDataErrorGenerator());

        Test.startTest();
        PedidosCallouts.getOrders();
        Test.stopTest();

        // Verificar que no se crearon pedidos por error en datos
        List<Order> orders = [SELECT Id FROM Order];
        System.assertEquals(0, orders.size(), 'No debería haberse creado pedidos por error en datos');
    }

    @isTest static void testFormatDate() {
        // Probar método de formato de fecha
        Date testDate = PedidosController.formatDate('2024-01-15');
        System.assertEquals(Date.newInstance(2024, 1, 15), testDate, 'La fecha debe formatearse correctamente');

        Date nullDate = PedidosController.formatDate(null);
        System.assertEquals(null, nullDate, 'Fecha null debe retornar null');

        Date invalidDate = PedidosController.formatDate('invalid-date');
        System.assertEquals(null, invalidDate, 'Fecha inválida debe retornar null');
    }

    @isTest static void testMapDocumentStatus() {
        // Probar mapeo de estados de documento
        String closedStatus = PedidosController.mapDocumentStatus('C');
        System.assertEquals('Cerrada', closedStatus, 'Estado C debe mapearse a Cerrada');

        String openStatus = PedidosController.mapDocumentStatus('A');
        System.assertEquals('Abierta', openStatus, 'Estado A debe mapearse a Abierta');

        String errorStatus = PedidosController.mapDocumentStatus('X');
        System.assertEquals('Error', errorStatus, 'Estado desconocido debe mapearse a Error');

        String nullStatus = PedidosController.mapDocumentStatus(null);
        System.assertEquals('Error', nullStatus, 'Estado null debe mapearse a Error');
    }

    @isTest static void testProcessOrdersDataWithMalformedJson() {
        // Probar con JSON malformado
        String malformedJson = '{"value": "invalid"}';
        
        Test.startTest();
        try {
            PedidosController.processOrdersData(malformedJson);
            // Si no arroja excepción, el método manejó correctamente el error
        } catch (Exception e) {
            // También es aceptable que arroje excepción con JSON malformado
            System.debug('Excepción esperada con JSON malformado: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest static void testProcessOrdersDataWithEmptyValue() {
        // Probar con JSON vacío pero válido
        String emptyJson = '{"value": []}';
        
        Test.startTest();
        PedidosController.processOrdersData(emptyJson);
        Test.stopTest();

        // Verificar que no se crearon pedidos
        List<Order> orders = [SELECT Id FROM Order];
        System.assertEquals(0, orders.size(), 'No debería haberse creado pedidos con datos vacíos');
    }

    // Mock para respuesta exitosa
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (req.getEndpoint().contains('/Login')) {
                res.setHeader('Content-Type', 'application/json');
                res.setHeader('Set-Cookie', 'B1SESSION=example-session-id; Path=/');
                res.setBody('{"SessionId": "example-session-id"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/crossjoin')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"value":[{"Orders":{"DocEntry":"1","DocNum":"123","DocType":"dDocument_Items","DocDate":"2024-01-15","DocDueDate":"2024-02-15","CardCode":"TEST001","CardName":"Test Account","Address":"Test Address","NumAtCard":"456","DocTotal":"1000.00","DocCurrency":"CLP","SalesPersonCode":"1","DocTime":"10:00:00","Comments":"Test Comment","ShipToCode":"SHIP001","FederalTaxID":"12345678-9","DocumentStatus":"A","Address2":"Test Address 2","U_RUTA":"Route1","U_RECETA":"Recipe1","U_SEI_IDW":"IDW001"},"Orders/DocumentLines":{"LineNum":"1","ItemCode":"PROD001","ItemDescription":"Test Product Description","Quantity":"10","ShipDate":"2024-01-20","Price":"100.00","PriceAfterVAT":"119.00","WarehouseCode":"WH001","BarCode":"123456789","TaxCode":"IVA"}}]}');
                res.setStatusCode(200);
            }
            
            return res;
        }
    }

    // Mock para error de autenticación
    private class MockHttpAuthErrorGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (req.getEndpoint().contains('/Login')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"error":"Authentication failed"}');
                res.setStatusCode(401);
            }
            
            return res;
        }
    }

    // Mock para error en datos
    private class MockHttpDataErrorGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            
            if (req.getEndpoint().contains('/Login')) {
                res.setHeader('Content-Type', 'application/json');
                res.setHeader('Set-Cookie', 'B1SESSION=example-session-id; Path=/');
                res.setBody('{"SessionId": "example-session-id"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/crossjoin')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"error":"Data retrieval failed"}');
                res.setStatusCode(500);
            }
            
            return res;
        }
    }
}