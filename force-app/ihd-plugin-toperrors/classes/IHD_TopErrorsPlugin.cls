/**
 * @description Card plugin for top error integrations list.
 */
public with sharing class IHD_TopErrorsPlugin implements IHD_CardPlugin {
  public String getCardName() {
    return 'Top Error Integrations';
  }

  public String getCardDescription() {
    return 'Ranked list of integrations by error count';
  }

  public String getComponentName() {
    return 'c-ihd-top-error-integrations';
  }

  public Integer getOrder() {
    return 20;
  }

  public Object getData(Map<String, Object> filters) {
    return IntegrationHealthService.getTopErrorIntegrations(5);
  }
}
