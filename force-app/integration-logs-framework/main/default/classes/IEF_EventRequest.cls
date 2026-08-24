/**
 * @description Request DTO for publishing integration events in bulk.
 */
public class IEF_EventRequest {
  public String integrationCode { get; set; }
  public String observationType { get; set; }
  public String correlationId { get; set; }
  public String parentEventId { get; set; }
  public String context { get; set; }
  public Datetime occurredAt { get; set; }

  public IEF_EventRequest() {
    this.occurredAt = Datetime.now();
  }

  public IEF_EventRequest(
    String integrationCode,
    String observationType,
    String correlationId,
    String parentEventId,
    String context
  ) {
    this.integrationCode = integrationCode;
    this.observationType = observationType;
    this.correlationId = correlationId;
    this.parentEventId = parentEventId;
    this.context = context;
    this.occurredAt = Datetime.now();
  }

  public IEF_EventRequest(
    String integrationCode,
    String observationType,
    String correlationId,
    String parentEventId,
    Map<String, Object> contextMap
  ) {
    this(
      integrationCode,
      observationType,
      correlationId,
      parentEventId,
      contextMap != null ? JSON.serialize(contextMap) : null
    );
  }
}
