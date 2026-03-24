/**
 * @description Callable implementation for optional dependency from other packages.
 * Allows ISVs and package developers to dynamically interact with the Integration
 * Events Framework without a hard package dependency.
 *
 * Usage:
 * Type ihdType = Type.forName('CallableIHD');
 * if (ihdType != null) {
 *     Callable ihd = (Callable) ihdType.newInstance();
 *     Object result = ihd.call('getActiveCardPlugins', null);
 * }
 */
public with sharing class CallableIHD implements System.Callable {
  /**
   * @description Executes the specified action with the given arguments.
   * @param action The action name (getActiveCardPlugins, getPluginData, isPluginEnabled, getDiscoveredFields)
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
      when else {
        throw new IllegalArgumentException(
          'CallableIHD: Unknown action: ' +
            action +
            '. Supported actions: getActiveCardPlugins, getPluginData, isPluginEnabled, getDiscoveredFields'
        );
      }
    }
  }

  private List<Map<String, Object>> getActiveCardPlugins() {
    List<IHD_Plugin__mdt> cardConfigs = IHD_PluginRegistry.getCardConfigs();
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (IHD_Plugin__mdt config : cardConfigs) {
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
        'CallableIHD: pluginName is required for getPluginData'
      );
    }
    List<IHD_Plugin__mdt> cardConfigs = IHD_PluginRegistry.getCardConfigs();
    for (IHD_Plugin__mdt config : cardConfigs) {
      if (config.DeveloperName == pluginName) {
        Object pluginInstance = IHD_PluginRegistry.getInstance(config);
        if (pluginInstance instanceof IHD_CardPlugin) {
          return ((IHD_CardPlugin) pluginInstance)
            .getData(new Map<String, Object>());
        }
      }
    }
    return null;
  }

  private Boolean isPluginEnabled(String pluginName) {
    if (String.isBlank(pluginName)) {
      return false;
    }
    // Query directly to avoid cache issues
    List<IHD_Plugin__mdt> configs = [
      SELECT Enabled__c
      FROM IHD_Plugin__mdt
      WHERE DeveloperName = :pluginName
      WITH USER_MODE
      LIMIT 1
    ];
    return !configs.isEmpty() && configs[0].Enabled__c;
  }

  private Set<String> getDiscoveredFields(String sobjectType) {
    if (String.isBlank(sobjectType)) {
      throw new IllegalArgumentException(
        'CallableIHD: sobjectType is required for getDiscoveredFields'
      );
    }
    return IHD_FieldDiscovery.getDiscoveredFields(sobjectType);
  }
}
