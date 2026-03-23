/**
 * @description Singleton registry that discovers and manages plugin implementations.
 * Reads IHD_Plugin__mdt records and instantiates plugins via Type.forName().
 * Caches active plugin instances per plugin type.
 */
public with sharing class IHD_PluginRegistry {

    /** @description Supported plugin types */
    public enum PluginType { TRIGGER, SERVICE, FIELD, CARD }

    @TestVisible
    private static Map<PluginType, List<IHD_Plugin__mdt>> cachedConfigs;
    @TestVisible
    private static Map<String, Object> cachedInstances;

    /**
     * @description Returns all enabled plugin configurations for a given type.
     * @param type The plugin type enum value
     * @return List of enabled IHD_Plugin__mdt records, sorted by DisplayOrder__c
     */
    public static List<IHD_Plugin__mdt> getPlugins(PluginType type) {
        if (cachedConfigs == null) {
            cachedConfigs = new Map<PluginType, List<IHD_Plugin__mdt>>();
        }
        if (!cachedConfigs.containsKey(type)) {
            List<IHD_Plugin__mdt> configs = [
                SELECT DeveloperName, Label, PluginType__c, ApexClassName__c,
                       Enabled__c, DisplayOrder__c, Description__c,
                       LwcComponentName__c, SObjectType__c, DeclaredFields__c,
                       CardLocation__c
                FROM IHD_Plugin__mdt
                WHERE Enabled__c = true AND PluginType__c = :type.name()
                ORDER BY DisplayOrder__c ASC NULLS LAST, DeveloperName ASC
                WITH USER_MODE
            ];
            cachedConfigs.put(type, configs);
        }
        return cachedConfigs.get(type);
    }

    /**
     * @description Returns an instantiated plugin for the given configuration.
     * Uses Type.forName() for dynamic class resolution. Returns null if the class
     * does not exist (e.g., uninstalled package) and logs a warning.
     * @param config The plugin configuration record
     * @return The instantiated plugin object, or null if not found
     */
    public static Object getInstance(IHD_Plugin__mdt config) {
        if (cachedInstances == null) {
            cachedInstances = new Map<String, Object>();
        }
        String cacheKey = config.ApexClassName__c;
        if (!cachedInstances.containsKey(cacheKey)) {
            Object instance = null;
            try {
                Type pluginType = Type.forName(config.ApexClassName__c);
                if (pluginType != null) {
                    instance = pluginType.newInstance();
                }
            } catch (Exception e) {
                System.debug(
                    LoggingLevel.WARN,
                    'IHD_PluginRegistry: Failed to instantiate plugin ' +
                    config.DeveloperName + ' (' + config.ApexClassName__c + '): ' + e.getMessage()
                );
            }
            cachedInstances.put(cacheKey, instance);
        }
        return cachedInstances.get(cacheKey);
    }

    /**
     * @description Returns all enabled trigger plugin configurations for a given SObject.
     * @param sobjectType The SObject API name (e.g., 'Integration_Log__c')
     * @return List of enabled trigger plugin configs for the SObject
     */
    public static List<IHD_Plugin__mdt> getTriggerConfigs(String sobjectType) {
        List<IHD_Plugin__mdt> allTriggerConfigs = getPlugins(PluginType.TRIGGER);
        if (String.isBlank(sobjectType)) {
            return allTriggerConfigs;
        }
        List<IHD_Plugin__mdt> filtered = new List<IHD_Plugin__mdt>();
        for (IHD_Plugin__mdt config : allTriggerConfigs) {
            if (config.SObjectType__c == sobjectType) {
                filtered.add(config);
            }
        }
        return filtered;
    }

    /**
     * @description Returns all enabled card plugin configurations.
     * @return List of enabled card plugin configs, sorted by DisplayOrder__c
     */
    public static List<IHD_Plugin__mdt> getCardConfigs() {
        return getPlugins(PluginType.CARD);
    }

    /**
     * @description Returns all enabled field plugin configurations.
     * @return List of enabled field plugin configs
     */
    public static List<IHD_Plugin__mdt> getFieldConfigs() {
        return getPlugins(PluginType.FIELD);
    }

    /**
     * @description Returns DeveloperNames of all active plugins across all types.
     * @return List of active plugin DeveloperNames
     */
    public static List<String> getActivePluginNames() {
        List<String> names = new List<String>();
        for (PluginType type : PluginType.values()) {
            for (IHD_Plugin__mdt config : getPlugins(type)) {
                names.add(config.DeveloperName);
            }
        }
        return names;
    }

    /**
     * @description Clears the cached configs and instances. Useful for testing.
     */
    @TestVisible
    private static void clearCache() {
        cachedConfigs = null;
        cachedInstances = null;
    }
}
