/**
 * @description Test stub implementing IEF_ActionPlugin for unit testing.
 */
@IsTest
public class TestStub_ActionPlugin implements IEF_ActionPlugin {
  public static Boolean shouldThrowException = false;
  public static Boolean shouldReturnRetry = false;
  public static Boolean executed = false;

  public IEF_ActionResult execute(IEF_ActionContext context) {
    executed = true;
    if (shouldThrowException) {
      throw new IllegalArgumentException('Simulated plugin failure');
    }
    if (shouldReturnRetry) {
      return IEF_ActionResult.retry('Simulated transient failure');
    }
    return IEF_ActionResult.success('Action executed successfully');
  }
}
