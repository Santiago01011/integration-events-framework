/**
 * @description Test stub implementing IEF_FieldPlugin for unit tests.
 */
@IsTest
public class TestStub_FieldPlugin implements IEF_FieldPlugin {
  public Set<String> getDeclaredFields() {
    return new Set<String>{ 'Name', 'CreatedDate' };
  }

  public String getFieldLabel(String apiName) {
    return apiName + ' Label';
  }
}
