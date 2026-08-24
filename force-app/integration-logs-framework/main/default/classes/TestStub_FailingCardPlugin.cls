/**
 * @description Test stub that fails to instantiate to exercise FAILED resolution path.
 */
@IsTest
public class TestStub_FailingCardPlugin implements IEF_CardPlugin {
  public TestStub_FailingCardPlugin() {
    throw new IllegalArgumentException('Simulated constructor failure');
  }

  public String getCardName() {
    return 'Failing Card';
  }

  public String getCardDescription() {
    return 'A card that fails on construction';
  }

  public String getComponentName() {
    return 'c-failing-card';
  }

  public Integer getOrder() {
    return 99;
  }

  public Object getData(Map<String, Object> filters) {
    return null;
  }
}
