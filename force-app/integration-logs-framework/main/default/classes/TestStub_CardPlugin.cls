/**
 * @description Test stub implementing IEF_CardPlugin for unit tests.
 */
@IsTest
public class TestStub_CardPlugin implements IEF_CardPlugin {
  public String getCardName() {
    return 'Test Card';
  }

  public String getCardDescription() {
    return 'A test card plugin';
  }

  public String getComponentName() {
    return 'c-test-card';
  }

  public Integer getOrder() {
    return 10;
  }

  /**
   * @description Test implementation — ignores all filters.
   */
  public Object getData(Map<String, Object> filters) {
    return new Map<String, Object>{ 'testKey' => 'testValue' };
  }
}
