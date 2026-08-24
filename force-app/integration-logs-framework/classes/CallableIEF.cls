/**
 * @description Callable implementation for optional dependency from other packages.
 * Allows ISVs and package developers to dynamically interact with the Integration
 * Events Framework without a hard package dependency.
 *
 * Usage:
 * Type iefType = Type.forName('CallableIEF');
 * if (iefType != null) {
 *     Callable ief = (Callable) iefType.newInstance();
 *     Object result = ief.call('getActiveCardPlugins', null);
 * }
 */
public with sharing class CallableIEF implements System.Callable {
  /**
   * @description Executes the specified action with the given arguments.
   * @param action The action name (getActiveCardPlugins, getPluginData, isPluginEnabled, getDiscoveredFields, getCompositionInfo)
   * @param args Map of arguments for the action
   * @return The result of the action
   */
  public Object call(String action, Map<String, Object> args) {
    switch on action {
      when 'getActivePlugins' {
        return getActiveCardPlugins();
      }
      when 'getActiveCardPlugins' {
        return getActiveCardPlugins();
      }
      when 'getPluginData' {
        String pluginName = (String) args?.get('pluginName');
        return getPluginData(pluginName);
      }
      when 'isPluginEnabled' {
        String pluginName = (String) args?.get('pluginName');
        return isPluginEnabled(pluginName);
      }
      when 'getDiscoveredFields' {
        String sobjectType = (String) args?.get('sobjectType');
        return getDiscoveredFields(sobjectType);
      }
      when 'getCompositionInfo' {
        return getCompositionInfo();
      }
      when else {
        throw new IllegalArgumentException(
          'CallableIEF: Unknown action: ' +
            action +
            '. Supported actions: getActiveCardPlugins, getPluginData, isPluginEnabled, getDiscoveredFields, getCompositionInfo'
        );
      }
    }
  }

  private List<Map<String, Object>> getActiveCardPlugins() {
    List<IEF_Plugin__mdt> cardConfigs = IEF_PluginRegistry.getCardConfigs();
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (IEF_Plugin__mdt config : cardConfigs) {
      Map<String, Object> plugin = new Map<String, Object>{
        'name' => config.DeveloperName,
        'label' => config.Label,
        'componentName' => config.LwcComponentName__c,
        'order' => config.DisplayOrder__c
      };
      result.add(plugin);
    }
    return result;
  }

  private Object getPluginData(String pluginName) {
    if (String.isBlank(pluginName)) {
      throw new IllegalArgumentException(
        'CallableIEF: pluginName is required for getPluginData'
      );
    }
    List<IEF_Plugin__mdt> cardConfigs = IEF_PluginRegistry.getCardConfigs();
    for (IEF_Plugin__mdt config : cardConfigs) {
      if (config.DeveloperName == pluginName) {
        IEF_PluginRegistry.Resolution res = IEF_PluginRegistry.resolve(config);
        if (res.status == 'ACTIVE' && res.instance instanceof IEF_CardPlugin) {
          return ((IEF_CardPlugin) res.instance)
            .getData(new Map<String, Object>());
        }
        return null;
      }
    }
    return null;
  }

  private Boolean isPluginEnabled(String pluginName) {
    if (String.isBlank(pluginName)) {
      return false;
    }
    // Query directly to avoid cache issues
    List<IEF_Plugin__mdt> configs = [
      SELECT Enabled__c
      FROM IEF_Plugin__mdt
      WHERE DeveloperName = :pluginName
      WITH USER_MODE
      LIMIT 1
    ];
    return !configs.isEmpty() && configs[0].Enabled__c;
  }

  private Set<String> getDiscoveredFields(String sobjectType) {
    if (String.isBlank(sobjectType)) {
      throw new IllegalArgumentException(
        'CallableIEF: sobjectType is required for getDiscoveredFields'
      );
    }
    return IEF_FieldDiscovery.getDiscoveredFields(sobjectType);
  }

  private List<IntegrationHealthWrappers.PluginCompositionEntry> getCompositionInfo() {
    return IntegrationHealthController.getCompositionInfo();
  }
}
