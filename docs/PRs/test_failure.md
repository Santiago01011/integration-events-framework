Run sf apex run test \

=== Test Results
TEST NAME OUTCOME MESSAGE RUNTIME (MS)
─────────────────────────────────────────────────────────────────────────────────────────── ─────── ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── ────────────
IHD_FieldDiscoveryTest.getDiscoveredFieldsCsv_emptyWhenNoFields Pass 67  
IHD_FieldDiscoveryTest.getDiscoveredFieldsCsv_returnsCommaSeparated Pass 28  
IHD_FieldDiscoveryTest.getDynamicFields_excludesNonExistentFields Pass 22  
IHD_FieldDiscoveryTest.getDynamicFields_handlesBlankDeclaredFields Pass 25  
IHD_FieldDiscoveryTest.getDynamicFields_includesDeclaredFields Pass 27  
IHD_FieldDiscoveryTest.getDynamicFields_returnsEmptyForNoFieldPlugins Pass 24  
IntegrationHealthControllerTest.testCanManagePlugins_returnsFalseWithoutPermission Pass 69  
IntegrationHealthControllerTest.testCanManagePlugins_returnsTrueWithPermission Pass 476  
IntegrationHealthControllerTest.testController_CatchBlocks Pass 365  
IntegrationHealthControllerTest.testController_SuccessPaths_Management Pass 254  
IntegrationHealthControllerTest.testDeployRegistryEntry Pass 22  
IntegrationHealthControllerTest.testGetFilterOptions Pass 84  
IntegrationHealthControllerTest.testGetHourlyTrend_empty Pass 434  
IntegrationHealthControllerTest.testGetHourlyTrend_happyPath Pass 88  
IntegrationHealthControllerTest.testGetHourlyTrend_singleLog Pass 265  
IntegrationHealthControllerTest.testGetIntegrationSummaries Pass 86  
IntegrationHealthControllerTest.testGetIntegrationSummaries_DetailedView Pass 88  
IntegrationHealthControllerTest.testGetLogDetail_ErrorPaths Pass 72  
IntegrationHealthControllerTest.testGetLogDetail_Security Pass 98  
IntegrationHealthControllerTest.testGetRecentLogs_EdgeCases Pass 121  
IntegrationHealthControllerTest.testGetRecentLogs_ReturnsData Pass 127  
IntegrationHealthControllerTest.testGetRecentLogs_SpecificFilters Pass 158  
IntegrationHealthControllerTest.testGetRecentLogs_WithDateFilters Pass 151  
IntegrationHealthControllerTest.testGetRecentLogs_WithSearch Pass 142  
IntegrationHealthControllerTest.testGetRegisteredPlugins_returnsAll Pass 17  
IntegrationHealthControllerTest.testGetSeverityCounts_allSameType Pass 235  
IntegrationHealthControllerTest.testGetSeverityCounts_empty Pass 196  
IntegrationHealthControllerTest.testGetSeverityCounts_happyPath Pass 93  
IntegrationHealthControllerTest.testGetTopErrorIntegrations_empty Pass 204  
IntegrationHealthControllerTest.testGetTopErrorIntegrations_happyPath Pass 82  
IntegrationHealthControllerTest.testGetTopErrorIntegrations_topN Pass 133  
IntegrationHealthControllerTest.testIsAdminUser Pass 62  
IntegrationHealthControllerTest.testRefreshPluginCache_doesNotThrow Pass 8  
IntegrationHealthControllerTest.testSecurityEnforcement Pass 255  
IntegrationHealthControllerTest.testSyncHistoricalLogs Pass 70  
IntegrationHealthControllerTest.testTogglePluginEnabled_handlesError Fail System.AuraHandledException: sObject type 'IHD_Plugin**mdt' is not supported. If you are attempting to use a custom object, be sure to append the '**c' after the entity name. Please reference your WSDL or the describe call for the appropriate names.  
 Class.IntegrationEventPublisher.handleControllerError: line 154, column 1  
 Class.IntegrationHealthController.togglePluginEnabled: line 331, column 1  
 Class.IntegrationHealthControllerTest.testTogglePluginEnabled_handlesError: line 938, column 1  
IntegrationHealthControllerTest.testTogglePluginEnabled_unauthorizedThrowsException Pass 63  
IntegrationHealthControllerTest.testWrappersCoverage Pass 5  
IntegrationHealthServiceTest.deleteLog_DeletesRecord Pass 1073  
IntegrationHealthServiceTest.deleteLog_HandlesNullId Pass 665  
IntegrationHealthServiceTest.getEventChannel_ReturnsChannelPath Pass 697  
IntegrationHealthServiceTest.getFilterOptions_ReturnsWrapper Pass 696  
IntegrationHealthServiceTest.getHourlyTrend_DefaultHours_WhenNull Pass 731  
IntegrationHealthServiceTest.getHourlyTrend_PointStructure Pass 702  
IntegrationHealthServiceTest.getHourlyTrend_ReturnsEmpty_WhenNoLogs Pass 1373  
IntegrationHealthServiceTest.getHourlyTrend_ReturnsPoints_WhenLogsExist Pass 783  
IntegrationHealthServiceTest.getHourlyTrend_SinglePoint_NoDelta Pass 920  
IntegrationHealthServiceTest.getIntegrationSummaries_ExpandsByAttributes_WhenFlagSet Pass 722  
IntegrationHealthServiceTest.getIntegrationSummaries_HandlesNullFlags Pass 689  
IntegrationHealthServiceTest.getIntegrationSummaries_IncludesUnregistered_WhenFlagSet Pass 723  
IntegrationHealthServiceTest.getIntegrationSummaries_ReturnsList Pass 698  
IntegrationHealthServiceTest.getLogDetail_ReturnsWrapper_WhenLogExists Pass 722  
IntegrationHealthServiceTest.getLogDetail_ThrowsException_WhenIdIsNull Pass 692  
IntegrationHealthServiceTest.getLogDetail_ThrowsException_WhenLogNotFound Pass 680  
IntegrationHealthServiceTest.getPagedLogs_FiltersBy_IntegrationCode Pass 788  
IntegrationHealthServiceTest.getPagedLogs_ReturnsPage_WhenLogsExist Pass 984  
IntegrationHealthServiceTest.getPagedLogs_UseDefaultPageSize_WhenNullProvided Pass 821  
IntegrationHealthServiceTest.getRegistryInfo_ReturnsList Pass 683  
IntegrationHealthServiceTest.getSeverityCounts_MultipleTypes_WithDifferentSeverities Pass 824  
IntegrationHealthServiceTest.getSeverityCounts_ReturnsEmpty_WhenNoLogs Pass 933  
IntegrationHealthServiceTest.getSeverityCounts_ReturnsEntries_WhenLogsExist Pass 708  
IntegrationHealthServiceTest.getTopErrorIntegrations_DefaultTopN_WhenNull Pass 705  
IntegrationHealthServiceTest.getTopErrorIntegrations_DefaultTopN_WhenZero Pass 680  
IntegrationHealthServiceTest.getTopErrorIntegrations_RespectsTopN Pass 788  
IntegrationHealthServiceTest.getTopErrorIntegrations_ReturnsEmpty_WhenNoLogs Pass 885  
IntegrationHealthServiceTest.getTopErrorIntegrations_ReturnsRanked_WhenErrorsExist Pass 798  
IntegrationHealthServiceTest.updateLogObservation_HandlesBlankType Pass 659  
IntegrationHealthServiceTest.updateLogObservation_HandlesNullId Pass 648  
IntegrationHealthServiceTest.updateLogObservation_UpdatesRecord Fail System.DmlException: Update failed. First exception on row 0 with id a00cf00000FhQRgAAN; first error: INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY, insufficient access rights on cross-reference id: a00cf00000FhQRg: []  
 Class.IntegrationHealthService.updateLogObservation: line 337, column 1  
 Class.IntegrationHealthServiceTest.updateLogObservation_UpdatesRecord: line 347, column 1  
IHD_SObjectHandlerTest.execute_isCalledForTriggerOperation Pass 115  
IHD_SObjectHandlerTest.handlerCanBeCalledDirectly Pass 7  
IHD_SObjectHandlerTest.tryCatch_isolatesFailingPlugins Pass 55  
IntegrationEventTriggerTest.testTriggerCreatesLog Pass 170  
IntegrationEventTriggerTest.testTriggerMultipleEvents Pass 93  
IntegrationRegistryServiceTest.deployRegistryEntry_HandlesOptionalFields_WhenNull Pass 27  
IntegrationRegistryServiceTest.deployRegistryEntry_ReturnsJobId_WhenValidInput Pass 10  
IntegrationRegistryServiceTest.deployRegistryEntry_ThrowsException_WhenCodeIsBlank Pass 6  
IntegrationRegistryServiceTest.deployRegistryEntry_ThrowsException_WhenCodeIsNull Pass 5  
IntegrationRegistryServiceTest.registryDeployCallback_HandlesComplexFailure Pass 112  
IntegrationRegistryServiceTest.sanitizeDeveloperName_ComplexCases Pass 19  
IntegrationRegistryServiceTest.syncHistoricalLogsFuture_UpdatesLargeBatch Pass 113  
IntegrationHealthSelectorTest.fieldExists_ReturnsFalse_ForInvalidField Pass 1051  
IntegrationHealthSelectorTest.fieldExists_ReturnsTrue_ForValidField Pass 716  
IntegrationHealthSelectorTest.filterAccessible_ExcludesNonExistentFields Pass 698  
IntegrationHealthSelectorTest.filterAccessible_ReturnsAccessibleFields Pass 689  
IntegrationHealthSelectorTest.filterAccessible_ReturnsEmpty_ForBlankInput Pass 679  
IntegrationHealthSelectorTest.filterAccessible_ReturnsEmpty_ForNullInput Pass 811  
IntegrationHealthSelectorTest.getEvaluationRules_ReturnsList Pass 718  
IntegrationHealthSelectorTest.getHourlyTrend_ReturnsAggregates_WhenLogsExist Pass 774  
IntegrationHealthSelectorTest.getHourlyTrend_ReturnsEmpty_WhenNoLogs Pass 1081  
IntegrationHealthSelectorTest.getIntegrationDefinitions_ReturnsMap Pass 680  
IntegrationHealthSelectorTest.getLogById_ReturnsLog_WhenExists Pass 720  
IntegrationHealthSelectorTest.getLogById_ReturnsNull_WhenNotFound Pass 700  
IntegrationHealthSelectorTest.getLogCountsByCode_ReturnsAggregates Pass 681  
IntegrationHealthSelectorTest.getLogCountsByIntegrationCode_ReturnsAggregates_WhenLogsExist Pass 742  
IntegrationHealthSelectorTest.getLogCountsByIntegrationCode_ReturnsEmpty_WhenNoLogs Pass 911  
IntegrationHealthSelectorTest.getLogFieldsCsv_ExcludesInaccessibleFields_ForRestrictedUser Pass 350  
IntegrationHealthSelectorTest.getLogFieldsCsv_ReturnsBaseFields_WhenNoPluginFields Pass 782  
IntegrationHealthSelectorTest.getLogSummaries_ReturnsAggregates Pass 869  
IntegrationHealthSelectorTest.getSeverityCounts_ReturnsAggregates_WhenLogsExist Pass 735  
IntegrationHealthSelectorTest.getSeverityCounts_ReturnsEmpty_WhenNoLogs Pass 890  
IntegrationHealthSelectorTest.isAdminUser_ReturnsBoolean Pass 715  
IntegrationHealthSelectorTest.queryLogs_FiltersBy_CorrelationId Pass 754  
IntegrationHealthSelectorTest.queryLogs_FiltersBy_IntegrationCode Pass 833  
IntegrationHealthSelectorTest.queryLogs_ReturnsResults_WhenLogsExist Pass 826  
IntegrationHealthSelectorTest.queryLogs_SupportsSearch_WhenProvided Pass 803  
IntegrationContextServiceTest.testAaa_InitializationWithRealCMDT Pass 28  
IntegrationContextServiceTest.testInitializationFallbackLogic Pass 10  
IntegrationContextServiceTest.testNormalizationCaseInsensitive Pass 5  
IntegrationContextServiceTest.testNormalizationNullOrEmpty Pass 4  
IntegrationContextServiceTest.testNormalizationUnregisteredCode Pass 6  
IntegrationContextServiceTest.testNormalizationWithRegisteredCode Pass 6  
IHD_PluginRegistryTest.getActivePluginNames_returnsAllEnabled Pass 12  
IHD_PluginRegistryTest.getCardConfigs_returnsCardPlugins Pass 6  
IHD_PluginRegistryTest.getFieldConfigs_returnsFieldPlugins Pass 5  
IHD_PluginRegistryTest.getInstance_cachesInstance Pass 10  
IHD_PluginRegistryTest.getInstance_returnsInstanceForValidClass Pass 9  
IHD_PluginRegistryTest.getInstance_returnsNullForMissingClass Pass 5  
IHD_PluginRegistryTest.getPlugins_excludesDisabledPlugins Pass 6  
IHD_PluginRegistryTest.getPlugins_returnsEmptyWhenNoPlugins Pass 18  
IHD_PluginRegistryTest.getPlugins_returnsEnabledPluginsByType Pass 6  
IHD_PluginRegistryTest.getTriggerConfigs_filtersBySObjectType Pass 5  
IntegrationLogCleanupBatchTest.testBatchCleanup Pass 1922  
IntegrationLogCleanupBatchTest.testBatchCleanupRetention Pass 294  
IntegrationLogCleanupBatchTest.testScheduling Pass 261  
IntegrationEventPublisherTest.testDMLSafetyGuard Pass 2648  
IntegrationEventPublisherTest.testEmitAndTriggerFlow Pass 97  
IntegrationEventPublisherTest.testEmitWithMap Pass 94  
IntegrationEventPublisherTest.testFieldTruncation Pass 73  
IntegrationEventPublisherTest.testKillSwitchBlocksDisabledIntegration Pass 98  
IntegrationEventPublisherTest.testUnregisteredIntegrationIsAllowed Pass 85  
IntegrationLogHandlerTest.handleEvents_CreatesLogs_WhenEventsProvided Pass 135  
IntegrationLogHandlerTest.handleEvents_DoesNothing_WhenEmptyList Pass 11  
IntegrationLogHandlerTest.handleEvents_DoesNothing_WhenNullInput Pass 9  
IntegrationLogHandlerTest.handleEvents_HandlesBulk_When200Events Pass 161  
CallableIHDTest.call_getActiveCardPlugins_returnsPluginNames Pass 6  
CallableIHDTest.call_getActivePlugins_returnsPluginNames Pass 5  
CallableIHDTest.call_getDiscoveredFields_missingSobjectType Pass 5  
CallableIHDTest.call_getDiscoveredFields_returnsFields Pass 74  
CallableIHDTest.call_getPluginData_missingPluginName Pass 4  
CallableIHDTest.call_getPluginData_returnsData Pass 15  
CallableIHDTest.call_isPluginEnabled_returnsFalse Pass 24  
CallableIHDTest.call_isPluginEnabled_returnsTrue Pass 7  
CallableIHDTest.call_unknownAction_throwsException Pass 4  
CallableIHDTest.callableInterface_implementsSystemCallable Pass 2  
=== Apex Code Coverage by Class
CLASSES PERCENT UNCOVERED LINES  
──────────────────────────── ─────── ─────────────────────
IntegrationLogTriggerHandler 100%  
IHD_TriggerContext 100%  
IntegrationHealthWrappers 89% 71,73,75,184,186,...
IntegrationHealthSelector 92% 88,89,90,92,94,...  
IntegrationLogCleanupBatch 100%  
CallableIHD 94% 26,81,86  
IHD_SObjectHandler 89% 36,45  
IntegrationContextService 100%  
IHD_PluginRegistry 38% 52,62,152,153,177,...
IHD_FieldDiscovery 97% 37  
IntegrationRegistryService 90% 70,71,72,79,80,...  
IntegrationHealthService 83% 34,35,36,79,156,...  
IntegrationLogHandler 68% 61,62,63,65,67,...  
IntegrationEventPublisher 87% 36,37,38,132,133,...
IntegrationHealthController 62% 32,44,73,74,75,...  
IntegrationLogTrigger 100%  
IntegrationEventTrigger 100%  
=== Test Setup Time by Test Class for Run 707cf00000lt3VH
TEST SETUP METHOD NAME SETUP TIME
───────────────────────────────────────────── ──────────
IHD_FieldDiscoveryTest.setupTestData 11  
IntegrationHealthControllerTest.setupTestData 901  
IntegrationHealthServiceTest.makeData 109  
IHD_SObjectHandlerTest.setupTestData 27  
IntegrationHealthSelectorTest.makeData 103  
IHD_PluginRegistryTest.setupTestData 15  
IntegrationLogCleanupBatchTest.setup 406  
CallableIHDTest.setupTestData 19  
=== Test Summary
NAME VALUE  
─────────────────── ─────────────────────────────
Outcome Failed  
Tests Ran 153  
Pass Rate 99%  
Fail Rate 1%  
Skip Rate 0%  
Test Run Id 707cf00000lt3VH  
Test Setup Time 1591 ms  
Test Execution Time 55433 ms  
Test Total Time 57024 ms  
Org Id 00Dcf0000083yFxEAI  
Username test-f2d1l9osb29m@example.com
Org Wide Coverage 77%  
Error: Process completed with exit code 100.
