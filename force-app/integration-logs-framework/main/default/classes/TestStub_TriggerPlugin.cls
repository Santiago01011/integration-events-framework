/**
 * @description Test stub implementing IEF_TriggerPlugin for unit tests.
 * Tracks execution and can be configured to throw exceptions.
 */
@IsTest
public class TestStub_TriggerPlugin implements IEF_TriggerPlugin {
  public static Boolean shouldThrow = false;
  public static Boolean wasExecuted = false;
  public static Integer executionCount = 0;

  public void execute(IEF_Plugin__mdt config, IEF_TriggerContext context) {
    executionCount++;
    wasExecuted = true;
    if (shouldThrow) {
      throw new System.IllegalArgumentException('Test plugin exception');
    }
  }

  public static void reset() {
    shouldThrow = false;
    wasExecuted = false;
    executionCount = 0;
  }
}
