@isTest
@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
public class ContactsCalloutsTest {

    @isTest static void testGetContacts() {
        // Crear Account de prueba
        Account testAccount = new Account(
            Name = 'Test Account',
            Clientes_ID__c = 'TEST001'
        );
        insert testAccount;

        // Configurar el mock HTTP
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Ejecutar método
        Test.startTest();
        ContactsCallouts.getContacts();
        Test.stopTest();

        // Verificar que se creó el contacto
        List<Contact> contacts = [SELECT Id, LastName, FirstName, ID_Externo_Contactos__c FROM Contact];
        System.assert(!contacts.isEmpty(), 'Debe haberse creado al menos un contacto');
    }

    @isTest static void testGetContactsAuthFailure() {
        // Configurar mock de error de autenticación
        Test.setMock(HttpCalloutMock.class, new MockHttpAuthErrorGenerator());

        Test.startTest();
        ContactsCallouts.getContacts();
        Test.stopTest();

        // Verificar que no se crearon contactos por error de auth
        List<Contact> contacts = [SELECT Id FROM Contact];
        System.assertEquals(0, contacts.size(), 'No debería haberse creado contactos por error de autenticación');
    }

    @isTest static void testGetContactsDataError() {
        // Crear Account de prueba
        Account testAccount = new Account(
            Name = 'Test Account',
            Clientes_ID__c = 'TEST001'
        );
        insert testAccount;

        // Configurar mock de error en datos
        Test.setMock(HttpCalloutMock.class, new MockHttpDataErrorGenerator());

        Test.startTest();
        ContactsCallouts.getContacts();
        Test.stopTest();

        // Verificar que no se crearon contactos por error en datos
        List<Contact> contacts = [SELECT Id FROM Contact];
        System.assertEquals(0, contacts.size(), 'No debería haberse creado contactos por error en datos');
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
                res.setBody('{"value":[{"BusinessPartners":{"CardCode":"TEST001","CardName":"Test Account"},"BusinessPartners/ContactEmployees":{"Name":"Test Contact","FirstName":"Contact","MobilePhone":"123456789","Email":"test@example.com"}}]}');
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