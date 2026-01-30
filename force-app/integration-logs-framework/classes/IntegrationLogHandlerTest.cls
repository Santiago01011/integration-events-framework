/**
 * @description Test class for IntegrationLogHandler.
 * Validates platform event to custom object conversion logic.
 */
@IsTest
private class IntegrationLogHandlerTest {
  @IsTest
  static void handleEvents_CreatesLogs_WhenEventsProvided() {
    List<IntegrationEvent__e> events = new List<IntegrationEvent__e>{
      new IntegrationEvent__e(
        IntegrationCode__c = 'SAP_ORDERS',
        ObservationType__c = 'HTTP_REQUEST',
        CorrelationId__c = 'corr-123',
        ParentEventId__c = null,
        Context__c = '{"url": "https://api.sap.com"}',
        OccurredAt__c = Datetime.now()
      ),
      new IntegrationEvent__e(
        IntegrationCode__c = 'SF_CONTACTS',
        ObservationType__c = 'DML_INSERT',
        CorrelationId__c = 'corr-456',
        ParentEventId__c = 'parent-123',
        Context__c = '{"recordCount": 5}',
        OccurredAt__c = Datetime.now()
      )
    };

    Test.startTest();
    IntegrationLogHandler.handleEvents(events);
    Test.stopTest();

    List<Integration_Log__c> logs = [
      SELECT
        IntegrationCode__c,
        ObservationType__c,
        CorrelationId__c,
        Normalized_Context__c
      FROM Integration_Log__c
      ORDER BY IntegrationCode__c
    ];

    System.assertEquals(2, logs.size(), 'Should create 2 logs');
    System.assertEquals(
      'SAP_ORDERS',
      logs[0].IntegrationCode__c,
      'First log should be SAP_ORDERS'
    );
    System.assertEquals(
      'SF_CONTACTS',
      logs[1].IntegrationCode__c,
      'Second log should be SF_CONTACTS'
    );
    System.assertNotEquals(
      null,
      logs[0].Normalized_Context__c,
      'Normalized context should be set'
    );
  }

  @IsTest
  static void handleEvents_DoesNothing_WhenNullInput() {
    Test.startTest();
    IntegrationLogHandler.handleEvents(null);
    Test.stopTest();

    List<Integration_Log__c> logs = [SELECT Id FROM Integration_Log__c];
    System.assertEquals(
      0,
      logs.size(),
      'Should not create logs for null input'
    );
  }

  @IsTest
  static void handleEvents_DoesNothing_WhenEmptyList() {
    Test.startTest();
    IntegrationLogHandler.handleEvents(new List<IntegrationEvent__e>());
    Test.stopTest();

    List<Integration_Log__c> logs = [SELECT Id FROM Integration_Log__c];
    System.assertEquals(
      0,
      logs.size(),
      'Should not create logs for empty list'
    );
  }

  @IsTest
  static void handleEvents_HandlesBulk_When200Events() {
    List<IntegrationEvent__e> events = new List<IntegrationEvent__e>();
    for (Integer i = 0; i < 200; i++) {
      events.add(
        new IntegrationEvent__e(
          IntegrationCode__c = 'BULK_TEST_' + i,
          ObservationType__c = 'BULK_OP',
          CorrelationId__c = 'bulk-' + i,
          Context__c = '{"index": ' + i + '}',
          OccurredAt__c = Datetime.now()
        )
      );
    }

    Test.startTest();
    IntegrationLogHandler.handleEvents(events);
    Test.stopTest();

    List<Integration_Log__c> logs = [SELECT Id FROM Integration_Log__c];
    System.assertEquals(200, logs.size(), 'Should create 200 logs in bulk');
  }
}
