/**
 * @description Queueable job for incremental synchronization of Products from SAP B1.
 * Uses the State-Chaining Batch pattern to handle paginated API calls.
 * Initiates ProductosBatchJob which processes one page at a time and chains to the next.
 * @deprecated Use the chaining batch job pattern directly with ProductosBatchJob instead.
 */
public class ProductosIntegrationJob implements Queueable, Database.AllowsCallouts {
  private String baseURL;
  private String dbName;
  private String username;
  private String password;
  private String lastSyncDateStr;
  private String mockPayload;

  public ProductosIntegrationJob(
    String baseURL,
    String dbName,
    String username,
    String password
  ) {
    this(baseURL, dbName, username, password, '2025-08-01', null);
  }

  public ProductosIntegrationJob(
    String baseURL,
    String dbName,
    String username,
    String password,
    String lastSyncDateStr,
    String mockPayload
  ) {
    this.baseURL = baseURL;
    this.dbName = dbName;
    this.username = username;
    this.password = password;
    this.lastSyncDateStr = lastSyncDateStr != null ? lastSyncDateStr : '2025-08-01';
    this.mockPayload = mockPayload;
  }

  public void execute(QueueableContext context) {
    try {
      ProductosBatchJob batch = new ProductosBatchJob(
        this.baseURL,
        this.dbName,
        this.username,
        this.password,
        this.dbName,
        this.lastSyncDateStr,
        null,
        null,
        this.mockPayload
      );
      
      Database.executeBatch(batch, 1);
      
      System.debug('✅ ProductosBatchJob chain started for ' + this.dbName);
      
    } catch (Exception ex) {
      String jobId = context != null ? String.valueOf(context.getJobId()) : null;
      IntegrationEventPublisher.publishError(
        'Productos',
        ex,
        'Failed to start ProductosBatchJob chain',
        jobId
      );
    }
  }
}
