/*
 * Quick script to demonstrate calling SAP B1 using the SAPB1ApiService class.
 *
 * It uses the existing SAPB1ApiService class which wraps RestClient.
 */

String baseURL = 'https://cmk.cloudseidor.com:50000/b1s/v1';
String database = Label.BBDD_PROFAR;
String username = Label.USUARIO_INT;
String password = Label.PASS_PROFAR;
// String database = Label.BBDD_CMK;
// String username = Label.USUARIO_INT;
// String password = Label.PASS_CMK;

SAPB1ApiService svc = new SAPB1ApiService(baseURL, database, username, password);

try {
    svc.authenticate();
    // Build the OData endpoint.
    String path = '/$crossjoin(Items,Manufacturers,ItemGroups)?$expand=' + EncodingUtil.urlEncode('Manufacturers($select=ManufacturerName),Items($select=ItemCode,UpdateDate,ItemName,U_SEI_PA,U_SEI_GEN,U_SEI_ROT,U_Departamento,U_Categoria,U_SubCategoria,Valid,BarCode,U_SEI_FAM,U_SEI_SUBFAM,Mainsupplier,DefaultWarehouse),ItemGroups($select=GroupName)', 'UTF-8') + '&$filter=' + EncodingUtil.urlEncode('Items/Manufacturer eq Manufacturers/Code and Items/ItemsGroupCode eq ItemGroups/Number and Items/Valid eq \'Y\' and Items/UpdateDate gt \'2025-08-01\'', 'UTF-8');
    HttpResponse resp = svc.getWithAuthentication(path + '&$top=10');
    System.debug('Status: ' + resp.getStatusCode());
    System.debug('Body: ' + resp.getBody());
} catch (Exception e) {
    // In a script we can log; in production code throw or handle properly
    System.debug('Callout failed: ' + e.getMessage());
}
