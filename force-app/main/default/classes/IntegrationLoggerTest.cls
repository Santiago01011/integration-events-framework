@IsTest
private class IntegrationLoggerTest {

    @IsTest
    static void testLogSuccess() {
        Map<String, Object> summaryMap = new Map<String, Object>{
            'Pedidos' => 100,
            'Productos' => 50,
            'Facturas' => 25
        };

        Test.startTest();

        IntegrationLogger.logSuccess('Test', summaryMap, 'jobId123');

        Test.stopTest();
    }

    @IsTest
    static void testLogError() {
        Map<String, Object> summaryMap = new Map<String, Object>{
            'Pedidos' => 10,
            'Productos' => 5
        };

        Test.startTest();

        IntegrationLogger.logError('Test', summaryMap, 'jobId456');

        Test.stopTest();
    }

    @IsTest
    static void testLogSuccessWithEmptyMap() {
        Map<String, Object> summaryMap = new Map<String, Object>();

        Test.startTest();

        IntegrationLogger.logSuccess('Empty Test', summaryMap, 'jobId789');

        Test.stopTest();
    }

    @IsTest
    static void testLogErrorWithException() {
        Map<String, Object> summaryMap = new Map<String, Object>{
            'Pedidos' => 5
        };

        Test.startTest();

        try {
            throw new IllegalArgumentException('Test exception');
        } catch (Exception ex) {
            IntegrationLogger.logError('Exception Test', summaryMap, 'jobIdException');
        }

        Test.stopTest();
    }
}