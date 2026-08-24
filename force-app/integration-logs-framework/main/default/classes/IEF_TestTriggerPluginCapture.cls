/**
 * Test trigger plugin that captures the trigger context for verification.
 */
@IsTest
public class IEF_TestTriggerPluginCapture implements IEF_TriggerPlugin {
  public static IEF_Plugin__mdt lastConfig;
  public static IEF_TriggerContext lastContext;
  public static Integer executionCount = 0;

  public void execute(IEF_Plugin__mdt config, IEF_TriggerContext context) {
    executionCount++;
    lastConfig = config;
    lastContext = context;
  }

  public static void reset() {
    lastConfig = null;
    lastContext = null;
    executionCount = 0;
  }
}
