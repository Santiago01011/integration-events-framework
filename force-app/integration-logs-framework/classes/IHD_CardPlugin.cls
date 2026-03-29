/**
 * @description Interface for dashboard card plugin implementations.
 * Plugins implementing this interface render cards in the Summary tab.
 */
public interface IHD_CardPlugin {
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
   * @return Component name (e.g., 'c-ihd-severity-breakdown')
   */
  String getComponentName();

  /**
   * @description Returns the display order for the card.
   * @return Order number (lower = first)
   */
  Integer getOrder();

  /**
   * @description Fetches data for this card with the given filters.
   * @param filters Map of filter criteria from the dashboard
   * @return Object data to pass to the LWC component
   */
  Object getData(Map<String, Object> filters);
}
