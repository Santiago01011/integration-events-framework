@IsTest
private class SAPB1ApiServiceTest {
    
    private class MockSAPHttpResponse implements HttpCalloutMock {
        private Map<String, Object> responseByEndpoint;
        
        public MockSAPHttpResponse(Map<String, Object> responseByEndpoint) {
            this.responseByEndpoint = responseByEndpoint;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setHeader('Set-Cookie', 'B1SESSION=test-session-cookie; path=/');
                res.setBody('{"SessionId":"test-session"}');
            } else if (req.getEndpoint().contains('/Items')) {
                res.setStatusCode(200);
                Map<String, Object> response = new Map<String, Object>{
                    'value' => new List<Object>{
                        new Map<String, Object>{
                            'ItemCode' => 'PROD001',
                            'ItemName' => 'Product 1',
                            'U_CFA_GRP_ART' => 'Group A'
                        }
                    }
                };
                res.setBody(JSON.serialize(response));
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":"Not found"}');
            }
            
            return res;
        }
    }
    
    @IsTest
    static void testAuthentication() {
        Test.setMock(HttpCalloutMock.class, new MockSAPHttpResponse(null));
        
        Test.startTest();
        SAPB1ApiService sapService = new SAPB1ApiService('TestCredential', 'TESTDB', 'user', 'pass');
        sapService.authenticate();
        Test.stopTest();
        
        System.assertNotEquals(null, sapService);
    }
    
    @IsTest
    static void testGetWithAuthentication() {
        Test.setMock(HttpCalloutMock.class, new MockSAPHttpResponse(null));
        
        Test.startTest();
        SAPB1ApiService sapService = new SAPB1ApiService('TestCredential', 'TESTDB', 'user', 'pass');
        HttpResponse response = sapService.getWithAuthentication('/Items');
        Test.stopTest();
        
        System.assertEquals(200, response.getStatusCode());
        System.assert(response.getBody().contains('PROD001'));
    }
    
    @IsTest
    static void testFetchAllPaginated() {
        Test.setMock(HttpCalloutMock.class, new MockSAPHttpResponse(null));
        
        Test.startTest();
        SAPB1ApiService sapService = new SAPB1ApiService('TestCredential', 'TESTDB', 'user', 'pass');
        List<Map<String, Object>> results = sapService.fetchAllPaginated('/Items');
        Test.stopTest();
        
        System.assertEquals(1, results.size());
        System.assertEquals('PROD001', results[0].get('ItemCode'));
    }
}
