/**
 * @description Queueable job for incremental synchronization of Orders from SAP B1.
 * Uses the State-Chaining Batch pattern to handle paginated API calls.
 * Initiates PedidosBatchJob which processes one page at a time and chains to the next.
 */
public without sharing class PedidosIntegrationJob implements Queueable, Database.AllowsCallouts {
    private String baseURL;
    private String DBName;
    private String username;
    private String password;
    private String lastSyncDateStr;
    private String mockPayload;
    
    public PedidosIntegrationJob(String baseURL, String DBName, String username, String password) {
        this(baseURL, DBName, username, password, '2025-08-01', null);
    }

    public PedidosIntegrationJob(
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
            PedidosBatchJob batch = new PedidosBatchJob(
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
            
            System.debug('✅ PedidosBatchJob chain started for ' + this.DBName);
            
        } catch (Exception ex) {
            IntegrationEventPublisher.publishError(
                'PedidosIntegrationJob.execute',
                ex,
                'Failed to start PedidosBatchJob chain',
                jobId
            );
        }
    }
}
