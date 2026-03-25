/**
 * @description Test stub implementing IHD_FieldPlugin for unit tests.
 */
@IsTest
public class TestStub_FieldPlugin implements IHD_FieldPlugin {
  public Set<String> getDeclaredFields() {
    return new Set<String>{ 'Name', 'CreatedDate' };
  }

  public String getFieldLabel(String apiName) {
    return apiName + ' Label';
  }
}
