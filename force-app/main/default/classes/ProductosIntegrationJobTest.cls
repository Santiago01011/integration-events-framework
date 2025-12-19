@IsTest
private class ProductosIntegrationJobTest {
    private class MockSAPProductsResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/Login')) {
                res.setStatusCode(200);
                res.setHeader('Set-Cookie', 'B1SESSION=test-session; path=/');
                res.setBody('{"SessionId":"test"}');
            } else if (req.getEndpoint().contains('$crossjoin')) {
                res.setStatusCode(200);
                // Mock the complex OData crossjoin response with nested structure
                Map<String, Object> response = new Map<String, Object>{
                    'value' => new List<Object>{
                        new Map<String, Object>{
                            'Manufacturers' => new Map<String, Object>{
                                'ManufacturerName' => 'Test Manufacturer'
                            },
                            'Items' => new Map<String, Object>{
                                'ItemCode' => 'TEST001',
                                'ItemName' => 'Test Product',
                                'U_SEI_PA' => 'Test Active Ingredient',
                                'U_SEI_GEN' => 'FALSO',
                                'U_SEI_ROT' => 'FALSO',
                                'U_Departamento' => 'Test Department',
                                'U_Categoria' => 'Test Category',
                                'U_SubCategoria' => 'Test SubCategory',
                                'Valid' => 'Y',
                                'BarCode' => '123456789',
                                'U_SEI_FAM' => 'Test Family',
                                'U_SEI_SUBFAM' => 'COSMETICO',
                                'Mainsupplier' => 'Test Supplier'
                            },
                            'ItemGroups' => new Map<String, Object>{
                                'GroupName' => 'Test Group'
                            }
                        }
                    }
                };
                res.setBody(JSON.serialize(response));
            }
            
            return res;
        }
    }
    
    @IsTest
    static void testExecuteSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockSAPProductsResponse());
        
        Test.startTest();
        ProductosIntegrationJob job = new ProductosIntegrationJob('TestCredential', 'TESTDB', 'user', 'pass');
        System.enqueueJob(job);
        Test.getEventBus().deliver(); // Force async execution
        Test.stopTest();
        
        List<Product2> products = [SELECT Id, ProductCode, Name, Principio_activo__c, Generico__c, Laboratorio__c, Grupo_de_articulos__c FROM Product2 WHERE ProductCode = 'TEST001'];
        System.assertEquals(1, products.size());
        System.assertEquals('Test Product', products[0].Name);
        System.assertEquals('Test Active Ingredient', products[0].Principio_activo__c);
        System.assertEquals('FALSO', products[0].Generico__c);
        System.assertEquals('Test Manufacturer', products[0].Laboratorio__c);
        System.assertEquals('Test Group', products[0].Grupo_de_articulos__c);
    }

    /**
     * @description Test error handling when JSON payload is invalid.
     * In this case the mock payload has an invalid ItemCode (non-string).
     * The job should catch the error and log it without creating any products.
     */
    @IsTest
    static void testExecuteFailForJSON() {
        String mockPayload = '{"odata.metadata":"$metadata#Collection(Edm.ComplexType)","value":[{"Manufacturers":{"ManufacturerName":"Mock Manufacturer"},"Items":{"ItemCode":ERROR,"ItemName":"Mock Product","U_SEI_PA":"Mock Ingredient","U_SEI_GEN":"VERDADERO","Valid":"Y"},"ItemGroups":{"GroupName":"Mock Group"}}]}';
        
        Test.startTest();
        ProductosIntegrationJob job = new ProductosIntegrationJob('TestCredential', 'TESTDB', 'user', 'pass', mockPayload);
        Id jobId = System.enqueueJob(job);
        Test.getEventBus().deliver();
        Test.stopTest();
        
        // Assert that an error log was created
        List<Integration_Log__c> errorLogs = [SELECT Id, Name, Message__c, StackTrace__c, Context__c FROM Integration_Log__c WHERE Context__c = 'ProductosIntegrationJob.execute'];
        System.assertEquals(1, errorLogs.size(), 'Expected 1 error log to be created');
        System.assert(errorLogs[0].Message__c.contains('expected a valid value'), 'Error message should mention JSON parsing failure');
        System.assert(errorLogs[0].StackTrace__c.contains('ProductosIntegrationJob.execute'), 'Stack trace should reference the execute method');
        System.assertEquals('ProductosIntegrationJob.execute', errorLogs[0].Context__c, 'Context should match the error location');
        
        // Assert that no products were created due to the error
        List<Product2> products = [SELECT Id FROM Product2];
        System.assertEquals(0, products.size(), 'No products should be created when JSON parsing fails');
    }
    
    /**
     * @description Test error handling when JSON payload has invalid data.
     * In this case the mock payload has an Item with missing required fields.
     * The controller should log an error about skipped products.
     */
    @IsTest
    static void testExecuteFailForData() {
        String mockPayload = '{"odata.metadata":"$metadata#Collection(Edm.ComplexType)","value":[{"Manufacturers":{"ManufacturerName":"Mock Manufacturer"},"Items":{"U_SEI_PA":"Mock Ingredient","U_SEI_GEN":"VERDADERO","Valid":"Y"},"ItemGroups":{"GroupName":"Mock Group"}}]}';
        
        Test.startTest();
        ProductosIntegrationJob job = new ProductosIntegrationJob('TestCredential', 'TESTDB', 'user', 'pass', mockPayload);
        Id jobId = System.enqueueJob(job);
        Test.getEventBus().deliver();
        Test.stopTest();
        
        // Assert that an error log was created for skipped products
        List<Integration_Log__c> errorLogs = [SELECT Id, Name, Message__c, Context__c FROM Integration_Log__c WHERE Context__c = 'ProductosController.processProductList'];
        System.assertEquals(1, errorLogs.size(), 'Expected 1 error log to be created for skipped products');
        System.assert(errorLogs[0].Message__c.contains('Skipped'), 'Error message should mention skipped products');
        System.assert(errorLogs[0].Message__c.contains('ItemCode'), 'Error message should mention ItemCode');
        System.assertEquals('ProductosController.processProductList', errorLogs[0].Context__c, 'Context should match the controller method');
        
        // Assert that no products were created due to missing ItemCode
        List<Product2> products = [SELECT Id FROM Product2];
        System.assertEquals(0, products.size(), 'No products should be created when ItemCode is missing');
    }

    @IsTest
    static void testExecuteWithMockPayload() {
        // Test the mock payload functionality without callouts
        String mockPayload = '{"odata.metadata":"$metadata#Collection(Edm.ComplexType)","value":[{"Manufacturers":{"ManufacturerName":"Mock Manufacturer"},"Items":{"ItemCode":"MOCK001","ItemName":"Mock Product","U_SEI_PA":"Mock Ingredient","U_SEI_GEN":"VERDADERO","Valid":"Y"},"ItemGroups":{"GroupName":"Mock Group"}}]}';
        
        Test.startTest();
        ProductosIntegrationJob job = new ProductosIntegrationJob('TestCredential', 'TESTDB', 'user', 'pass', mockPayload);
        Id jobId = System.enqueueJob(job);
        Test.getEventBus().deliver(); // Force async execution
        Test.stopTest();
        
        // Debug: Check if job executed
        System.debug('Job ID: ' + jobId);
        
        List<Product2> products = [SELECT Id, ProductCode, Name, Principio_activo__c, Generico__c, Laboratorio__c, Grupo_de_articulos__c FROM Product2 WHERE ProductCode = 'MOCK001'];
        System.debug('Found products: ' + products.size());
        if (!products.isEmpty()) {
            System.debug('Product: ' + products[0]);
        }
        
        System.assertEquals(1, products.size(), 'Expected 1 product to be created');
        System.assertEquals('Mock Product', products[0].Name);
        System.assertEquals('Mock Ingredient', products[0].Principio_activo__c);
        System.assertEquals('VERDADERO', products[0].Generico__c);
        System.assertEquals('Mock Manufacturer', products[0].Laboratorio__c);
        System.assertEquals('Mock Group', products[0].Grupo_de_articulos__c);
    }
    
    @IsTest
    static void testControllerProcessProductList() {
        // Test the controller method directly
        List<Map<String, Object>> testData = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Manufacturers' => new Map<String, Object>{'ManufacturerName' => 'Test Manufacturer'},
                'Items' => new Map<String, Object>{
                    'ItemCode' => 'CTRL001',
                    'ItemName' => 'Controller Test Product',
                    'U_SEI_PA' => 'Test Ingredient',
                    'U_SEI_GEN' => 'FALSO',
                    'Valid' => 'Y'
                },
                'ItemGroups' => new Map<String, Object>{'GroupName' => 'Test Group'}
            }
        };
        
        Test.startTest();
        Database.UpsertResult[] results = ProductosController.processProductList(testData);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Expected 1 upsert result');
        System.assert(results[0].isSuccess(), 'Upsert should succeed');
        
        // Debug: Check all products
        List<Product2> allProducts = [SELECT Id, ProductCode, Name, Productos_ID__c FROM Product2];
        System.debug('All products in org: ' + allProducts);
        
        List<Product2> products = [SELECT Id, ProductCode, Name, Principio_activo__c, Generico__c, Laboratorio__c, Grupo_de_articulos__c FROM Product2 WHERE ProductCode = 'CTRL001'];
        System.debug('Found products with CTRL001: ' + products.size());
        
        if (!products.isEmpty()) {
            System.debug('Product details: ' + products[0]);
        }
        
        System.assertEquals(1, products.size(), 'Expected 1 product to be created');
        System.assertEquals('Controller Test Product', products[0].Name);
        System.assertEquals('Test Ingredient', products[0].Principio_activo__c);
        System.assertEquals('Test Manufacturer', products[0].Laboratorio__c);
        System.assertEquals('Test Group', products[0].Grupo_de_articulos__c);
    }
}
