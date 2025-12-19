/**
 * Test script to enqueue PedidosIntegrationJob with LIVE SAP B1 callout
 * 
 * This will:
 * 1. Enqueue PedidosIntegrationJob (Queueable)
 * 2. Which enqueues PedidosBatchJob (Batch with AllowsCallouts)
 * 3. Batch makes real callout to SAP B1 OData endpoint
 * 4. Processes Orders/DocumentLines via pagination
 * 5. Delegates to PedidosController for mapping and upsert
 * 
 * WARNING: This performs REAL callouts to SAP B1. Only run when testing live integration.
 */

String baseURL = 'https://cmk.cloudseidor.com:50000/b1s/v1';
String database = Label.BBDD_PROFAR;
String username = Label.USUARIO_INT;
String password = Label.PASS_PROFAR;

// No mock payload - will perform real SAP B1 callout
PedidosIntegrationJob job = new PedidosIntegrationJob(baseURL, database, username, password);
Id qid = System.enqueueJob(job);
System.debug('✅ Enqueued PedidosIntegrationJob id=' + qid);
System.debug('   LIVE callout to SAP B1');
System.debug('   Database: ' + database);
System.debug('   Will enqueue PedidosBatchJob for processing');
