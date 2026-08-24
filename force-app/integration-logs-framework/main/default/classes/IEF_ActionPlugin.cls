/**
 * @description Contract interface for Action Plugins.
 * Consumer packages implement this interface to perform business automations,
 * API callouts, or async processing triggered by incoming integration events.
 */
public interface IEF_ActionPlugin {
  /**
   * @description Executes the business action.
   * @param context Context containing the event log, correlation info, and retry count.
   * @return IEF_ActionResult indicating SUCCESS, RETRY, or FATAL_FAILURE.
   */
  IEF_ActionResult execute(IEF_ActionContext context);
}
