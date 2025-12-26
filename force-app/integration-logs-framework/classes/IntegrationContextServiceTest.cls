@IsTest
private class IntegrationContextServiceTest {

    private static Map<String, String> getMockMappings() {
        return new Map<String, String> {
            'order' => 'Orders',
            'cart' => 'Checkout'
        };
    }

    @IsTest
    static void testNormalizationLogic() {
        IntegrationContextService.setTestContextMappings(getMockMappings());

        Test.startTest();
        String match1 = IntegrationContextService.normalize('CreateOrderJob');
        String match2 = IntegrationContextService.normalize('ShoppingCart_Update');
        String noMatch = IntegrationContextService.normalize('UnknownProcess');
        String empty = IntegrationContextService.normalize(null);
        Test.stopTest();

        System.assertEquals('Orders', match1, 'Should map "order" to "Orders"');
        System.assertEquals('Checkout', match2, 'Should map "cart" to "Checkout"');
        System.assertEquals('UnknownProcess', noMatch, 'Should return original if no match found');
        System.assertEquals('Debug', empty, 'Null/Empty should return generic fallback');
    }
}