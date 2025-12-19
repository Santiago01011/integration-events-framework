/**
 * @description Queueable job for incremental synchronization of Invoices from SAP B1.
 * Uses the State-Chaining Batch pattern to handle paginated API calls.
 * Initiates FacturasBatchJob which processes one page at a time and chains to the next.
 */
public class FacturasIntegrationJob implements Queueable, Database.AllowsCallouts {
    private String baseURL;
    private String DBName;
    private String username;
    private String password;
    private String lastSyncDateStr;
    private String mockPayload;
    
    public FacturasIntegrationJob(String baseURL, String DBName, String username, String password) {
        this(baseURL, DBName, username, password, '2025-08-01', null);
    }

    public FacturasIntegrationJob(
        String baseURL,
        String DBName,
        String username,
        String password,
        String lastSyncDateStr,
        String mockPayload
    ) {
        this.baseURL = baseURL;
        this.DBName = DBName;
        this.username = username;
        this.password = password;
        this.lastSyncDateStr = lastSyncDateStr != null ? lastSyncDateStr : '2025-08-01';
        this.mockPayload = mockPayload;
    }
    
    public void execute(QueueableContext context) {
        String jobId = context != null ? String.valueOf(context.getJobId()) : null;
        
        try {
            FacturasBatchJob batch = new FacturasBatchJob(
                this.baseURL,
                this.DBName,
                this.username,
                this.password,
                this.lastSyncDateStr,
                null,
                null,
                this.mockPayload
            );
            
            Database.executeBatch(batch, 1);
            
            System.debug('✅ FacturasBatchJob chain started for ' + this.DBName);
            
        } catch (Exception ex) {
            IntegrationEventPublisher.publishError(
                'FacturasIntegrationJob.execute',
                ex,
                'Failed to start FacturasBatchJob chain',
                jobId
            );
        }
    }
}
