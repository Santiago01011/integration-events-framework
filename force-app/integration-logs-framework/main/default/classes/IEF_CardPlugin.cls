/**
 * @description Interface for dashboard card plugin implementations.
 * Plugins implementing this interface render cards in the Summary tab.
 */
public interface IEF_CardPlugin {
  /**
   * @description Returns the display name of the card.
   * @return Card name for the header
   */
  String getCardName();

  /**
   * @description Returns a brief description of the card.
   * @return Description for tooltip/help text
   */
  String getCardDescription();

  /**
   * @description Returns the LWC component name to render.
   * @return Component name (e.g., 'c-ief-severity-breakdown')
   */
  String getComponentName();

  /**
   * @description Returns the display order for the card.
   * @return Order number (lower = first)
   */
  Integer getOrder();

  /**
   * @description Fetches data for this card with the given filters.
   * Supported keys: search, observationType, integrationCode,
   * correlationId, fromOccurredAt, toOccurredAt.
   * Implementations should either apply each provided filter or document
   * which keys are intentionally ignored.
   * @param filters Map of filter criteria from the dashboard (may be empty but never null)
   * @return Object data to pass to the LWC component
   */
  Object getData(Map<String, Object> filters);
}
