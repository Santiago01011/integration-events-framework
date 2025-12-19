/**
 * Test script to enqueue ProductosIntegrationJob with N items in payload
 * for load testing and error handling validation.
 */
Integer N = 5;

List<Object> vals = new List<Object>();
for (Integer i = 1; i <= N; i++) {
    Map<String,Object> itemDetails = new Map<String,Object>{
        'ItemCode' => 'LOAD' + String.valueOf(i),
        // 'ItemName' => String.valueOf(i),
        'U_CFA_GRP_ART' => 'TestGroup' + String.valueOf(i),
        'BarCode' => 'LOAD' + String.valueOf(i)
    };
    Map<String, Object> productNode = new Map<String, Object>{
        'Items' => itemDetails
    };
    vals.add(productNode);
}
Map<String,Object> root = new Map<String,Object>{ 'value' => vals };
String payload = JSON.serialize(root);

// enqueue job with mock payload
ProductosIntegrationJob job = new ProductosIntegrationJob('SAP_B1_PROFAR','TESTDB','user','pass', payload);
Id qid = System.enqueueJob(job);
System.debug('Enqueued ProductosIntegrationJob id=' + qid + ' with N=' + N);
