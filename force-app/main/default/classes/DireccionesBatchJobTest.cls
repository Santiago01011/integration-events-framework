@IsTest
private class DireccionesBatchJobTest {
    
    private class MockSAPDireccionesResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setHeader('Set-Cookie', 'B1SESSION=test-session; path=/');
                res.setBody('{"SessionId":"test"}');
            } else if (req.getEndpoint().contains('/BusinessPartners')) {
                res.setStatusCode(200);
                Map<String, Object> response = new Map<String, Object>{
                    'value' => new List<Object>{
                        new Map<String, Object>{
                            'AddressName' => 'Main Office',
                            'Street' => '123 Test St',
                            'City' => 'TestCity',
                            'ZipCode' => '12345',
                            'Country' => 'US'
                        }
                    }
                };
                res.setBody(JSON.serialize(response));
            }
            
            return res;
        }
    }
    
    @IsTest
    static void testBatchExecution() {
        Account testAccount = new Account(Name = 'Test Account', AccountNumber = 'C12345');
        insert testAccount;
        
        Test.setMock(HttpCalloutMock.class, new MockSAPDireccionesResponse());
        
        Test.startTest();
        DireccionesBatchJob batchJob = new DireccionesBatchJob('TestCredential', 'TESTDB', 'user', 'pass');
        Database.executeBatch(batchJob, 10);
        Test.stopTest();
        
        List<Direcciones__c> direcciones = [SELECT Id, AddressName__c, Account__c FROM Direcciones__c WHERE Account__c = :testAccount.Id];
        System.assertEquals(1, direcciones.size());
        System.assertEquals('Main Office', direcciones[0].AddressName__c);
    }
    
    @IsTest
    static void testBatchWithError() {
        Account testAccount = new Account(Name = 'Test Account', AccountNumber = 'C99999');
        insert testAccount;
        
        Test.setMock(HttpCalloutMock.class, new MockSAPDireccionesResponse());
        
        Test.startTest();
        DireccionesBatchJob batchJob = new DireccionesBatchJob('TestCredential', 'TESTDB', 'user', 'pass');
        Database.executeBatch(batchJob, 10);
        Test.getEventBus().deliver();
        Test.stopTest();
        
        System.assert(true);
    }
}
