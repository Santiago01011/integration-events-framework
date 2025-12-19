@isTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
public class AccountsCalloutsTest {

    //prueba para la autenticación
    @isTest static void testAuthenticate() {
        // Configurar el mock HTTP
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Llamar a la autenticación
        accountsCallouts.authenticate();

        // Verificar que el SessionId se haya configurado correctamente
        System.assertNotEquals(null, accountsCallouts.sessionId, 'El SessionId no debería ser null después de la autenticación.');
    }

    //prueba para obtener las cuentas
    @isTest static void testGetAccounts() { // NOPMD
        // Configurar el mock HTTP
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Llamar al método de obtención de cuentas
        accountsCallouts.getAccounts();
    }

    // Clase mock para simular respuestas HTTP
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/Login')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"SessionId": "ejemploSessionId"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/BusinessPartners')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"value":[{"CardCode":"PN967942405","CardName":"OFFICIO S.A","CardType":"cSupplier","GroupCode":101,"Address":"MAR DEL SUR 7190","ZipCode":null,"MailAddress":"test@example.com","MailZipCode":null,"Phone1":null,"Phone2":null,"Fax":null,"ContactPerson":null,"Notes":null,"PayTermsGrpCode":2,"CreditLimit":0,"MaxCommitment":0,"DiscountPercent":0,"VatLiable":"vLiable","FederalTaxID":"96794240-5","PriceListNum":1,"SalesPersonCode":-1,"City":"Santiago","County":"Pudahuel","Country":"CL","MailCity":null,"MailCounty":null,"MailCountry":"CL","EmailAddress":null,"CardForeignName":null,"CurrentAccountBalance":0,"OpenOrdersBalance":0,"Valid":"tYES","Frozen":"tNO","ShipToDefault":"Ship To","U_SEI_GNRP":"FABRICACION DE MUEBLES PRINCIPALMENTE D","U_Estratificacion":null},{"CardCode":"PN121687720","CardName":"MARIA CAROLINA MORALES SILVA","CardType":"cSupplier","GroupCode":101,"Address":null,"ZipCode":null,"MailAddress":null,"MailZipCode":null,"Phone1":null,"Phone2":null,"Fax":null,"ContactPerson":null,"Notes":null,"PayTermsGrpCode":2,"CreditLimit":0,"MaxCommitment":0,"DiscountPercent":0,"VatLiable":"vLiable","FederalTaxID":"12168772-0","PriceListNum":1,"SalesPersonCode":-1,"City":null,"County":"LAS CONDES","Country":"CL","MailCity":null,"MailCounty":null,"MailCountry":null,"EmailAddress":null,"CardForeignName":null,"CurrentAccountBalance":0,"OpenOrdersBalance":0,"Valid":"tYES","Frozen":"tNO","ShipToDefault":null,"U_SEI_GNRP":null,"U_Estratificacion":null},{"CardCode":"PN969454408","CardName":"SOC. CONCESIONARIA AUTOPISTA CENTRAL S.A","CardType":"cCustomer","GroupCode":101,"Address":"SAN JOSE 1145","ZipCode":null,"MailAddress":null,"MailZipCode":null,"Phone1":null,"Phone2":null,"Fax":null,"ContactPerson":null,"Notes":null,"PayTermsGrpCode":2,"CreditLimit":0,"MaxCommitment":0,"DiscountPercent":0,"VatLiable":"vLiable","FederalTaxID":"96945440-8","PriceListNum":1,"SalesPersonCode":-1,"City":"Maipo","County":"San Bernardo","Country":"CL","MailCity":null,"MailCounty":null,"MailCountry":"CL","EmailAddress":null,"CardForeignName":null,"CurrentAccountBalance":-224276,"OpenOrdersBalance":0,"Valid":"tYES","Frozen":"tNO","ShipToDefault":"Ship To","U_SEI_GNRP":"SERVICIOS PRESTADOS POR CONCESIONARIOS","U_Estratificacion":null}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // 12/mayo/2025. Test de autenticación fallida por parte del servidor.
    @isTest static void testAuthenticateFailed() {
        // Definición de la respuesta que será errónea.
        HttpResponse mockResponse = new HttpResponse();
        mockResponse.setBody('{"Error":"Server Error"}');
        mockResponse.setStatusCode(500);

        // Configuración del mock HTTP con la respuesta errónea.
        Test.setMock(HttpCalloutMock.class, new MockHttp500ResponseGenerator());

        // Llamada a la autenticación.
        accountsCallouts.authenticate();

        // Verificación de falta de SessionId.
        System.assertEquals(null, accountsCallouts.sessionId, 'El SessionId debería ser null después de la autenticación fallida.');
    }

    // 12/may/2025. Mock de respuesta HTTP con error de servidor (500).
    private class MockHttp500ResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/Login')) {
                res.setHeader('Content-Type', 'application/json');
                res.setStatusCode(500);
            } else if (req.getEndpoint().contains('/BusinessPartners')) {
                res.setHeader('Content-Type', 'application/json');
                res.setStatusCode(500);
            }
            return res;
        }
    }

    // 13/mayo/2025. Test error de duplicidad en llave única.
    @isTest static void testGetDuplicateAccounts() { // NOPMD
        Test.setMock(HttpCalloutMock.class, new MockHttpDuplicateResponseGenerator());
        accountsCallouts.getAccounts();
    }

    // 13/may/2025. Mock de respuesta HTTP con error de duplicidad (dentro de los datos).
    private class MockHttpDuplicateResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/Login')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"SessionId": "ejemploSessionId"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/BusinessPartners')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"value":[{"CardCode":"PN121687720","CardName":"OFFICIO S.A","CardType":"cSupplier","GroupCode":101,"Address":"MAR DEL SUR 7190","ZipCode":null,"MailAddress":"test@example.com","MailZipCode":null,"Phone1":null,"Phone2":null,"Fax":null,"ContactPerson":null,"Notes":null,"PayTermsGrpCode":2,"CreditLimit":0,"MaxCommitment":0,"DiscountPercent":0,"VatLiable":"vLiable","FederalTaxID":"96794240-5","PriceListNum":1,"SalesPersonCode":-1,"City":"Santiago","County":"Pudahuel","Country":"CL","MailCity":null,"MailCounty":null,"MailCountry":"CL","EmailAddress":null,"CardForeignName":null,"CurrentAccountBalance":0,"OpenOrdersBalance":0,"Valid":"tYES","Frozen":"tNO","ShipToDefault":"Ship To","U_SEI_GNRP":"FABRICACION DE MUEBLES PRINCIPALMENTE D","U_Estratificacion":null},{"CardCode":"PN121687720","CardName":"OFFICIO S.A","CardType":"cSupplier","GroupCode":101,"Address":"MAR DEL SUR 7190","ZipCode":null,"MailAddress":"test@example.com","MailZipCode":null,"Phone1":null,"Phone2":null,"Fax":null,"ContactPerson":null,"Notes":null,"PayTermsGrpCode":2,"CreditLimit":0,"MaxCommitment":0,"DiscountPercent":0,"VatLiable":"vLiable","FederalTaxID":"96794240-5","PriceListNum":1,"SalesPersonCode":-1,"City":"Santiago","County":"Pudahuel","Country":"CL","MailCity":null,"MailCounty":null,"MailCountry":"CL","EmailAddress":null,"CardForeignName":null,"CurrentAccountBalance":0,"OpenOrdersBalance":0,"Valid":"tYES","Frozen":"tNO","ShipToDefault":"Ship To","U_SEI_GNRP":"FABRICACION DE MUEBLES PRINCIPALMENTE D","U_Estratificacion":null}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

    // 13/mayo/2025. Test Accounts que ya tenían definido Clientes_ID__c.
    @isTest static void testAccsWithClientes() { // NOPMD
        Test.startTest();
        Account acc = new Account(
            Name = 'Empresa S.A.',
            Clientes_ID__c = '123456789012345'
        );
        insert acc;
        Test.setMock(HttpCalloutMock.class, new MockHttpAccWithClientesResponseGenerator());
        accountsCallouts.getAccounts();
        Test.stopTest();
    }

    // 13/may/2025. Mock de respuesta HTTP con error de duplicidad (dentro de los datos).
    private class MockHttpAccWithClientesResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/Login')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"SessionId": "ejemploSessionId"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/BusinessPartners')) {
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"value":[{"Clientes_ID__c":"Clientes_ID__c"}]}');
                res.setStatusCode(200);
            }
            return res;
        }
    }

}