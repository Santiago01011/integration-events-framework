/**
 * @description Trigger plugin that appends the running user's name to Integration_Log__c.Context__c.
 * This plugin runs in AFTER_INSERT and AFTER_UPDATE, and safely ignores already-appended records.
 */
public with sharing class IHD_AppendUserToContextTriggerPlugin implements IHD_TriggerPlugin {
  @TestVisible
  public static void reset() {
    // no stateful tracking required for normal op
  }

  public void execute(IHD_Plugin__mdt config, IHD_TriggerContext context) {
    if (
      context == null ||
      context.newRecords == null ||
      context.newRecords.isEmpty()
    ) {
      return;
    }

    if (
      context.operationType != System.TriggerOperation.BEFORE_INSERT &&
      context.operationType != System.TriggerOperation.BEFORE_UPDATE
    ) {
      return;
    }

    String currentUserName = UserInfo.getName();
    String userSuffix = ' | User: ' + currentUserName;

    for (SObject record : context.newRecords) {
      if (!(record instanceof Integration_Log__c)) {
        continue;
      }

      Integration_Log__c log = (Integration_Log__c) record;
      String existingContext = log.Context__c;

      if (String.isBlank(existingContext)) {
        log.Context__c = 'User: ' + currentUserName;
      } else if (!existingContext.contains('User: ' + currentUserName)) {
        log.Context__c = existingContext + userSuffix;
      }
    }
  }
}
