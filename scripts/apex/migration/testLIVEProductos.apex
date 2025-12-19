/**
 * Executes a LIVE, paginated sync for Products.
 * * This script instantiates the *initial* batch job with a dynamic
 * date filter and enqueues its starter. The batch will then
 * chain-run itself until all pages are processed.
 */
try {
    // 1. Set Credentials (Ensure these Labels are correct!)
    String baseURL = 'https://cmk.cloudseidor.com:50000/b1s/v1';
    String database = Label.BBDD_CMK; // Or Label.BBDD_PROFAR
    String username = Label.USUARIO_INT;
    String password = Label.PASS_CMK;   // Or Label.PASS_PROFAR

    // 2. Set the Dynamic Date Filter (e.g., sync all products from yesterday)
    // String syncDate = Date.today().addDays(-1).format('yyyy-MM-dd');
    String syncDate = '2025-01-01';
    
    // 3. Create the initial batch job instance
    // We use the full 9-parameter constructor
    BasePaginatedBatchJob job = new ProductosBatchJob(
        baseURL,         // 1. baseURL
        database,        // 2. companyDB
        username,        // 3. username
        password,        // 4. password
        database,        // 5. dbName (as required by constructor)
        syncDate,        // 6. lastSyncDateStr (our dynamic filter)
        null,            // 7. nextLink (null to start from page 1)
        null,            // 8. summary (null to start a new summary)
        null             // 9. mockPayload (null for a live run)
    );

    // 4. Get its self-starter Queueable and enqueue it
    Id jobId = System.enqueueJob(job.getStarter()); //
    
    System.debug('✅ Successfully enqueued LIVE Products sync.');
    System.debug('Job ID: ' + jobId);
    System.debug('Filter: UpdateDate > ' + syncDate);

} catch (Exception e) {
    System.debug('❌ Failed to enqueue job: ' + e.getMessage());
}