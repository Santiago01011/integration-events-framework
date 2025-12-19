@IsTest
private class PedidosIntegrationJobTest {
    private class MockSAPOrdersResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setHeader('Set-Cookie', 'B1SESSION=test-session; path=/');
                res.setBody('{"SessionId":"test"}');
            } else if (req.getEndpoint().contains('$crossjoin')) {
                res.setStatusCode(200);
                Map<String, Object> response = new Map<String, Object>{
                    'value' => new List<Object>{
                        new Map<String, Object>{
                            'Orders' => new Map<String, Object>{
                                'DocEntry' => 100001,
                                'DocNum' => 5001,
                                'CardCode' => 'C001',
                                'DocDate' => '2024-01-15',
                                'DocDueDate' => '2024-01-20',
                                'DocTotal' => 150000,
                                'DocCurrency' => 'CLP',
                                'Comments' => 'Test order',
                                'DocStatus' => 'O'
                            },
                            'Orders/DocumentLines' => new Map<String, Object>{
                                'LineNum' => 0,
                                'ItemCode' => 'PROD001',
                                'Quantity' => 10,
                                'Price' => 15000,
                                'TaxCode' => 'IVA',
                                'ShipDate' => '2024-01-18'
                            }
                        }
                    }
                };
                res.setBody(JSON.serialize(response));
            }
            
            return res;
        }
    }
    
    @TestSetup
    static void setupData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Customer',
            SAP_ID__c = 'C001'
        );
        insert testAccount;
        
        // Create test Product
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            ProductCode = 'PROD001',
            Productos_ID__c = 'PROD001',
            IsActive = true
        );
        insert testProduct;
        
        // Get standard pricebook
        Id pricebookId = Test.getStandardPricebookId();
        
        // Create PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 15000,
            IsActive = true
        );
        insert pbe;
    }
    
    @IsTest
    static void testExecuteSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockSAPOrdersResponse());
        
        Test.startTest();
        PedidosIntegrationJob job = new PedidosIntegrationJob('TestCredential', 'TESTDB', 'user', 'pass');
        System.enqueueJob(job);
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Order> orders = [SELECT Id, Pedidos_ID__c, OrderNumber, AccountId, Pricebook2Id, TotalAmount FROM Order WHERE Pedidos_ID__c = '100001'];
        System.assertEquals(1, orders.size(), 'Expected 1 order to be created');
        System.assertEquals('100001', orders[0].Pedidos_ID__c, 'Order external ID should match DocEntry');
        
        List<OrderItem> orderItems = [SELECT Id, OrderId, Product2Id, Quantity, UnitPrice FROM OrderItem WHERE OrderId = :orders[0].Id];
        System.assertEquals(1, orderItems.size(), 'Expected 1 order item to be created');
        System.assertEquals(10, orderItems[0].Quantity, 'Quantity should match payload');
        System.assertEquals(15000, orderItems[0].UnitPrice, 'Unit price should match payload');
    }
    
    @IsTest
    static void testExecuteFailForJSON() {
        String mockPayload = '{"value":[{"Orders":{"DocEntry":ERROR,"DocNum":5001,"CardCode":"C001"},"Orders/DocumentLines":{"LineNum":0,"ItemCode":"PROD001"}}]}';
        
        Test.startTest();
        PedidosIntegrationJob job = new PedidosIntegrationJob('TestCredential', 'TESTDB', 'user', 'pass', mockPayload);
        System.enqueueJob(job);
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> errorLogs = [SELECT Id, Message__c, StackTrace__c, Context__c FROM Integration_Log__c WHERE Context__c = 'PedidosIntegrationJob.execute'];
        System.assertEquals(1, errorLogs.size(), 'Expected 1 error log to be created');
        System.assert(errorLogs[0].Message__c.contains('expected a valid value'), 'Error message should mention JSON parsing failure');
        
        List<Order> orders = [SELECT Id FROM Order];
        System.assertEquals(0, orders.size(), 'No orders should be created when JSON parsing fails');
    }
    
    @IsTest
    static void testMissingAccount() {
        String mockPayload = '{"value":[{"Orders":{"DocEntry":100002,"DocNum":5002,"CardCode":"C999","DocDate":"2024-01-15","DocDueDate":"2024-01-20","DocTotal":100000,"DocCurrency":"CLP"},"Orders/DocumentLines":{"LineNum":0,"ItemCode":"PROD001","Quantity":5,"Price":20000}}]}';
        
        Test.startTest();
        PedidosIntegrationJob job = new PedidosIntegrationJob('TestCredential', 'TESTDB', 'user', 'pass', mockPayload);
        System.enqueueJob(job);
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Integration_Log__c> errorLogs = [SELECT Id, Message__c, Context__c FROM Integration_Log__c WHERE Context__c = 'PedidosController.processOrderList'];
        System.assertEquals(1, errorLogs.size(), 'Expected 1 error log for missing account');
        System.assert(errorLogs[0].Message__c.contains('Skipped 1 orders due to missing Account'), 'Error message should mention skipped orders');
        System.assert(errorLogs[0].Message__c.contains('CardCode: C999'), 'Error message should include missing CardCode');
        
        List<Order> orders = [SELECT Id FROM Order WHERE Pedidos_ID__c = '100002'];
        System.assertEquals(0, orders.size(), 'Order should be skipped when account is missing');
    }
    
    @IsTest
    static void testMissingProduct() {
        String mockPayload = '{"value":[{"Orders":{"DocEntry":100003,"DocNum":5003,"CardCode":"C001","DocDate":"2024-01-15","DocDueDate":"2024-01-20","DocTotal":50000,"DocCurrency":"CLP"},"Orders/DocumentLines":{"LineNum":0,"ItemCode":"PROD999","Quantity":2,"Price":25000}}]}';
        
        Test.startTest();
        PedidosIntegrationJob job = new PedidosIntegrationJob('TestCredential', 'TESTDB', 'user', 'pass', mockPayload);
        System.enqueueJob(job);
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Order> orders = [SELECT Id FROM Order WHERE Pedidos_ID__c = '100003'];
        System.assertEquals(1, orders.size(), 'Order should be created even if line item is skipped');
        
        List<Integration_Log__c> errorLogs = [SELECT Id, Message__c, Context__c FROM Integration_Log__c WHERE Context__c = 'PedidosController.processOrderList' AND Message__c LIKE '%order lines%'];
        System.assertEquals(1, errorLogs.size(), 'Expected 1 error log for missing product');
        System.assert(errorLogs[0].Message__c.contains('Skipped 1 order lines due to missing lookups'), 'Error message should mention skipped lines');
        System.assert(errorLogs[0].Message__c.contains('ItemCode: PROD999'), 'Error message should include missing ItemCode');
        
        List<OrderItem> orderItems = [SELECT Id FROM OrderItem WHERE OrderId = :orders[0].Id];
        System.assertEquals(0, orderItems.size(), 'OrderItem should be skipped when product is missing');
    }
    
    @IsTest
    static void testExecuteWithMockPayload() {
        String mockPayload = '{"value":[{"Orders":{"DocEntry":100004,"DocNum":5004,"CardCode":"C001","DocDate":"2024-01-15","DocDueDate":"2024-01-20","DocTotal":75000,"DocCurrency":"CLP"},"Orders/DocumentLines":{"LineNum":0,"ItemCode":"PROD001","Quantity":5,"Price":15000}}]}';
        
        Test.startTest();
        PedidosIntegrationJob job = new PedidosIntegrationJob('TestCredential', 'TESTDB', 'user', 'pass', mockPayload);
        System.enqueueJob(job);
        Test.getEventBus().deliver();
        Test.stopTest();
        
        List<Order> orders = [SELECT Id, Pedidos_ID__c FROM Order WHERE Pedidos_ID__c = '100004'];
        System.assertEquals(1, orders.size(), 'Expected 1 order to be created from mock payload');
        
        List<OrderItem> orderItems = [SELECT Id, Quantity FROM OrderItem WHERE OrderId = :orders[0].Id];
        System.assertEquals(1, orderItems.size(), 'Expected 1 order item to be created from mock payload');
        System.assertEquals(5, orderItems[0].Quantity, 'Quantity should match mock payload');
    }
    
    @IsTest
    static void testControllerProcessOrderList() {
        Account acc = [SELECT Id FROM Account WHERE SAP_ID__c = 'C001' LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 WHERE ProductCode = 'PROD001' LIMIT 1];
        
        List<Map<String, Object>> orderNodes = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Orders' => new Map<String, Object>{
                    'DocEntry' => 100005,
                    'DocNum' => 5005,
                    'CardCode' => 'C001',
                    'DocDate' => '2024-01-15',
                    'DocDueDate' => '2024-01-20',
                    'DocTotal' => 60000,
                    'DocCurrency' => 'CLP',
                    'Comments' => 'Direct controller test',
                    'DocStatus' => 'O'
                },
                'Orders/DocumentLines' => new Map<String, Object>{
                    'LineNum' => 0,
                    'ItemCode' => 'PROD001',
                    'Quantity' => 4,
                    'Price' => 15000,
                    'TaxCode' => 'IVA',
                    'ShipDate' => '2024-01-18'
                }
            }
        };
        
        Test.startTest();
        PedidosController.ProcessResult result = PedidosController.processOrderList(orderNodes);
        Test.stopTest();
        
        System.assertEquals(1, result.ordersProcessed, 'Expected 1 order to be processed');
        System.assertEquals(1, result.ordersUpserted, 'Expected 1 order to be upserted');
        System.assertEquals(0, result.ordersSkipped, 'Expected 0 orders to be skipped');
        System.assertEquals(1, result.linesProcessed, 'Expected 1 line to be processed');
        System.assertEquals(1, result.linesUpserted, 'Expected 1 line to be upserted');
        System.assertEquals(0, result.linesSkipped, 'Expected 0 lines to be skipped');
        System.assertEquals(0, result.orderErrors.size(), 'Expected 0 order errors');
        System.assertEquals(0, result.lineErrors.size(), 'Expected 0 line errors');
        
        List<Order> orders = [SELECT Id FROM Order WHERE Pedidos_ID__c = '100005'];
        System.assertEquals(1, orders.size(), 'Expected 1 order to be created');
        
        List<OrderItem> orderItems = [SELECT Id, Quantity FROM OrderItem WHERE OrderId = :orders[0].Id];
        System.assertEquals(1, orderItems.size(), 'Expected 1 order item to be created');
        System.assertEquals(4, orderItems[0].Quantity, 'Quantity should match test data');
    }
}
