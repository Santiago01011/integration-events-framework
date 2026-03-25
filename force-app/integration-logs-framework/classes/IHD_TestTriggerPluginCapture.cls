/**
 * Test trigger plugin that captures the trigger context for verification.
 */
@IsTest
public class IHD_TestTriggerPluginCapture implements IHD_TriggerPlugin {
  public static IHD_Plugin__mdt lastConfig;
  public static IHD_TriggerContext lastContext;
  public static Integer executionCount = 0;

  public void execute(IHD_Plugin__mdt config, IHD_TriggerContext context) {
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
