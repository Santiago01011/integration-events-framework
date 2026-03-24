/**
 * @description Card plugin for severity breakdown donut chart.
 */
public with sharing class IHD_SeverityBreakdownPlugin implements IHD_CardPlugin {
  public String getCardName() {
    return 'Severity Breakdown';
  }

  public String getCardDescription() {
    return 'Donut chart showing event distribution by severity level';
  }

  public String getComponentName() {
    return 'c-ihd-severity-breakdown';
  }

  public Integer getOrder() {
    return 10;
  }

  public Object getData(Map<String, Object> filters) {
    return IntegrationHealthService.getSeverityCounts();
  }
}
