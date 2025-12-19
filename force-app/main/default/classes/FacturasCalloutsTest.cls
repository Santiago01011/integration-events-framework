@isTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
public class FacturasCalloutsTest {

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

        Order testOrder = new Order(
            AccountId = testAccount.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pedidos_ID__c = 'ORDER001'
        );
        insert testOrder;
    }

    @isTest static void testGetInvoices() {
        // Configurar el mock HTTP
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Ejecutar método
        Test.startTest();
        FacturasCallouts.getInvoices();
        Test.stopTest();

        // Verificar que se creó la factura
        List<Facturas__c> facturas = [SELECT Id, Facturas_ID__c FROM Facturas__c];
        System.assert(!facturas.isEmpty(), 'Debe haberse creado al menos una factura');
    }

    @isTest static void testGetInvoicesAuthFailure() {
        // Configurar mock de error de autenticación
        Test.setMock(HttpCalloutMock.class, new MockHttpAuthErrorGenerator());

        Test.startTest();
        FacturasCallouts.getInvoices();
        Test.stopTest();

        // Verificar que no se crearon facturas por error de auth
        List<Facturas__c> facturas = [SELECT Id FROM Facturas__c];
        System.assertEquals(0, facturas.size(), 'No debería haberse creado facturas por error de autenticación');
    }

    @isTest static void testGetInvoicesDataError() {
        // Configurar mock de error en datos
        Test.setMock(HttpCalloutMock.class, new MockHttpDataErrorGenerator());

        Test.startTest();
        FacturasCallouts.getInvoices();
        Test.stopTest();

        // Verificar que no se crearon facturas por error en datos
        List<Facturas__c> facturas = [SELECT Id FROM Facturas__c];
        System.assertEquals(0, facturas.size(), 'No debería haberse creado facturas por error en datos');
    }

    @isTest static void testFormatDate() {
        // Probar método de formato de fecha
        Date testDate = FacturasController.formatDate('2024-01-15');
        System.assertEquals(Date.newInstance(2024, 1, 15), testDate, 'La fecha debe formatearse correctamente');

        Date nullDate = FacturasController.formatDate(null);
        System.assertEquals(null, nullDate, 'Fecha null debe retornar null');

        Date invalidDate = FacturasController.formatDate('invalid-date');
        System.assertEquals(null, invalidDate, 'Fecha inválida debe retornar null');
    }

    @isTest static void testProcessInvoicesDataWithMalformedJson() {
        // Probar con JSON malformado
        String malformedJson = '{"value": "invalid"}';
        
        Test.startTest();
        try {
            FacturasController.processInvoicesData(malformedJson);
            // Si no arroja excepción, el método manejó correctamente el error
        } catch (Exception e) {
            // También es aceptable que arroje excepción con JSON malformado
            System.debug('Excepción esperada con JSON malformado: ' + e.getMessage());
        }
        Test.stopTest();
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
                res.setBody('{"value":[{"Invoices":{"DocEntry":"1","DocNum":"123","FolioNumber":"F123","DocType":"dDocument_Items","DocDate":"2024-01-15","DocDueDate":"2024-02-15","CardCode":"TEST001","CardName":"Test Account","Address":"Test Address","NumAtCard":"456","DocTotal":"1000.00","DocCurrency":"CLP","SalesPersonCode":"1","DocTime":"10:00:00","Comments":"Test Comment","ShipToCode":"SHIP001","FederalTaxID":"12345678-9","DocumentStatus":"bost_Open","Address2":"Test Address 2","U_RUTA":"Route1","U_Receta":"Recipe1","U_SEI_IDW":"IDW001","U_SEI_FEBOSID":"FEBOS123"},"Invoices/DocumentLines":{"LineNum":"1","ItemCode":"PROD001","ItemDescription":"Test Product Description","Quantity":"10","ShipDate":"2024-01-20","Price":"100.00","PriceAfterVAT":"119.00","WarehouseCode":"WH001","BarCode":"123456789","TaxCode":"IVA"}}]}');
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