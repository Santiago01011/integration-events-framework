# Permissions for IEF Agentforce Core Plugin

## Permission Sets

### Ief_AgentforceCore_Execute

- Label: IEF Agentforce Core Execute
- Purpose: Grants execution/read access required by the Agentforce Core plugin card.
- Scope:
  - Apex class access: `IntegrationHealthController`
  - Object read access: `Integration_Log__c`
  - Field read access: standard log fields plus Agentforce debug envelope fields (`AgentSessionId__c`, `ConversationId__c`, `AgentName__c`, `LlmModel__c`, `ReasoningStepType__c`, `ReasoningStepName__c`, `TopicName__c`, token metrics, prompt/tool/raw payload fields, `PersistDebugDetail__c`)

## Dependency Mapping

- Depends on core package contracts:
  - Apex: `IntegrationHealthController.getRecentLogs`
  - LMS channels: `IEF_Card_Registry__c`, `IEF_Plugin_Actions__c`
  - Dynamic registry module: `c/iefDynamicLoader`

## Role Assignment Matrix

- Integration Observer:
  - Assign `Ief_AgentforceCore_Execute`
  - Can view and use Agentforce Core Pulse card navigation.

- Integration Admin:
  - Assign `Ief_AgentforceCore_Execute`
  - Optionally combine with existing admin-oriented framework permission sets.

## Validation Checklist

- [ ] User can load dashboard with Agentforce Core card.
- [ ] User can see session pulse metrics and rows.
- [ ] User can click actionable rows and navigate to filtered logs.
- [ ] User can inspect prompt/tool/raw payload blocks in debug detail.
- [ ] User can inspect token and reasoning-step metadata when available.
- [ ] User cannot edit or delete `Integration_Log__c` through this permission set.
- [ ] Plugin still works with active dashboard filters.
