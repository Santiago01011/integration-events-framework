/**
 * @description Context object passed to trigger plugins containing trigger operation details.
 */
public class IEF_TriggerContext {
  /** @description The trigger operation type (BEFORE_INSERT, AFTER_INSERT, etc.) */
  @AuraEnabled
  public System.TriggerOperation operationType { get; private set; }

  /** @description The new records in the trigger */
  @AuraEnabled
  public List<SObject> newRecords { get; private set; }

  /** @description The old records in the trigger (null for inserts) */
  @AuraEnabled
  public List<SObject> oldRecords { get; private set; }

  /** @description Map of old records by ID (null for inserts) */
  @AuraEnabled
  public Map<Id, SObject> oldMap { get; private set; }

  /**
   * @description Constructs a trigger context from the current trigger variables.
   * @param operationType The System.TriggerOperation enum value
   * @param newRecords Trigger.new
   * @param oldRecords Trigger.old
   * @param oldMap Trigger.oldMap
   */
  public IEF_TriggerContext(
    System.TriggerOperation operationType,
    List<SObject> newRecords,
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
    this.operationType = operationType;
    this.newRecords = newRecords;
    this.oldRecords = oldRecords;
    this.oldMap = oldMap;
  }
}
