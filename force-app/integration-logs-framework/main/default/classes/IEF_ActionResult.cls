/**
 * @description Result object returned by an IEF_ActionPlugin implementation.
 * Signals outcome to the Core execution engine (SUCCESS, RETRY, FATAL_FAILURE).
 */
public class IEF_ActionResult {
  public enum Status {
    SUCCESS,
    RETRY,
    FATAL_FAILURE
  }

  public Status status { get; set; }
  public String message { get; set; }

  public IEF_ActionResult() {
    this.status = IEF_ActionResult.Status.SUCCESS;
  }

  public static IEF_ActionResult success(String message) {
    IEF_ActionResult res = new IEF_ActionResult();
    res.status = IEF_ActionResult.Status.SUCCESS;
    res.message = message;
    return res;
  }

  public static IEF_ActionResult retry(String reason) {
    IEF_ActionResult res = new IEF_ActionResult();
    res.status = IEF_ActionResult.Status.RETRY;
    res.message = reason;
    return res;
  }

  public static IEF_ActionResult fatalFailure(String reason) {
    IEF_ActionResult res = new IEF_ActionResult();
    res.status = IEF_ActionResult.Status.FATAL_FAILURE;
    res.message = reason;
    return res;
  }
}
