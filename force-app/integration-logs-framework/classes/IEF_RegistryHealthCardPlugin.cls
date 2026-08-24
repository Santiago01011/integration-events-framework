/**
 * @description Reference card provider that proves the IEF_CardPlugin seam end-to-end.
 * Delegates to IntegrationHealthController.getCompositionInfo() and returns the
 * effective plugin composition (resolved target, order, status, reason). This
 * dogfoods D6's getCompositionInfo surface and follows the exact
 * shell/register/lwc:is pattern so core stays plugin-agnostic.
 *
 * Filter contract (C3):
 * - Supported: none. The card ignores the filters map entirely; all rows are
 *   returned regardless of dashboard filter values. Callers may pass any filter
 *   keys — they are intentionally ignored. This is documented here per C3.
 * - Unsupported: search, observationType, integrationCode, correlationId,
 *   fromOccurredAt, toOccurredAt, and any future filter keys are ignored.
 */
public with sharing class IEF_RegistryHealthCardPlugin implements IEF_CardPlugin {
  @AuraEnabled(cacheable=false)
  public static List<IntegrationHealthWrappers.PluginCompositionEntry> getCardData(
    Map<String, Object> filters
  ) {
    return IntegrationHealthController.getCompositionInfo();
  }

  public Object getData(Map<String, Object> filters) {
    return getCardData(filters);
  }

  public String getCardName() {
    return 'Registry Health';
  }

  public String getCardDescription() {
    return 'Effective plugin composition including status and failure reasons.';
  }

  public String getComponentName() {
    return 'c-iefRegistryHealthCard';
  }

  public Integer getOrder() {
    return 99;
  }
}
