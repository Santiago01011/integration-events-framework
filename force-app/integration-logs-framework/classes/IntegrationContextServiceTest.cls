@IsTest
private class IntegrationContextServiceTest {

    private static Map<String, String> getFakeMappings() {
        return new Map<String, String>{
            'orders' => 'Orders',
            'products' => 'Products',
            'invoices' => 'Invoices',
            'addresses' => 'Addresses'
        };
    }

    @IsTest
    static void testNormalizeContexts() {
        IntegrationContextService.setTestContextMappings(getFakeMappings());

        Test.startTest();

        String result1 = IntegrationContextService.normalize('Ordersbatata');
        String result2 = IntegrationContextService.normalize('PRODUCTS_JOB');
        String result3 = IntegrationContextService.normalize('My Custom Job');
        String result4 = IntegrationContextService.normalize(null);
        String result5 = IntegrationContextService.normalize('   invoicesXYZ   ');
        String result6 = IntegrationContextService.normalize('');

        Test.stopTest();

        System.assertEquals('Orders', result1, 'Should normalize "Ordersbatata" to "Orders"');
        System.assertEquals('Products', result2, 'Should normalize "PRODUCTS_JOB" to "Products"');
        System.assertEquals('My Custom Job', result3, 'Should return original value trimmed when no keyword matches');
        System.assertEquals('Debug', result4, 'Should return "Debug" for null input');
        System.assertEquals('Invoices', result5, 'Should normalize with whitespace and case insensitivity');
        System.assertEquals('Debug', result6, 'Should return "Debug" for empty string');
    }

    @IsTest
    static void testNormalizeWithDifferentCases() {
        IntegrationContextService.setTestContextMappings(getFakeMappings());

        Test.startTest();

        String result1 = IntegrationContextService.normalize('ORDERS');
        String result2 = IntegrationContextService.normalize('orders');
        String result3 = IntegrationContextService.normalize('OrDeRs');
        String result4 = IntegrationContextService.normalize('AdDreSses_Batch');

        Test.stopTest();

        System.assertEquals('Addresses', result4, 'Should handle mixed case with special characters');
        System.assertEquals('Orders', result1, 'Should handle uppercase');
        System.assertEquals('Orders', result2, 'Should handle lowercase');
        System.assertEquals('Orders', result3, 'Should handle mixed case');
    }

    @IsTest
    static void testNormalizePerformance() {
        IntegrationContextService.setTestContextMappings(getFakeMappings());

        Test.startTest();

        for (Integer i = 0; i < 100; i++) {
            IntegrationContextService.normalize('Orders_Job_' + i);
        }

        Test.stopTest();
    }
}