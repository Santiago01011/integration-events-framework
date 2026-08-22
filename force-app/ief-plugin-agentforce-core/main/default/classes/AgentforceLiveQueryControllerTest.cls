@isTest
private class AgentforceLiveQueryControllerTest {
  @isTest
  static void testGetLiveSessionTrace_NullSessionId() {
    Test.startTest();
    String result = AgentforceLiveQueryController.getLiveSessionTrace(null);
    Test.stopTest();

    System.assertEquals(
      null,
      result,
      'Expected null result for null session Id'
    );
  }

  @isTest
  static void testGetLiveSessionTrace_ValidSessionId() {
    // Since we cannot reliably insert MessagingSession or Data Cloud objects in a package test
    // (they might not exist in the subscriber org), we test that the method executes
    // without throwing exceptions and returns the base JSON structure.

    String mockSessionId = '000000000000000AAA';

    Test.startTest();
    String result = AgentforceLiveQueryController.getLiveSessionTrace(
      mockSessionId
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null');

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      result
    );
    System.assert(
      payload.containsKey('trace'),
      'Payload should contain trace section'
    );

    Map<String, Object> trace = (Map<String, Object>) payload.get('trace');
    System.assertEquals(
      mockSessionId,
      trace.get('dcSessionId'),
      'dcSessionId should match input'
    );
  }

  @isTest
  static void testGetRecentSessionIds() {
    Test.startTest();
    List<Map<String, String>> results = AgentforceLiveQueryController.getRecentSessionIds();
    Test.stopTest();

    System.assertNotEquals(null, results, 'Results list should not be null');
    // Since we don't mock the data cloud objects here, it might return empty or mock records if created
    // The test ensures the method completes without exceptions
  }
}
