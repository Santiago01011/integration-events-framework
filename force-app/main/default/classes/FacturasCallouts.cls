public class FacturasCallouts {
    private static final String SERVER = label.Clinical_server;
    private static final String PORT = label.Clinical_port;
    private static final String LOGIN_ENDPOINT = SERVER + ':' + PORT + '/b1s/v1/Login';
    private static final String INVOICE_ENDPOINT_TEMPLATE = SERVER + ':' + PORT + '/b1s/v1/$crossjoin(Invoices,Invoices/DocumentLines)?$expand=Invoices($select=DocEntry,DocNum,FolioNumber,DocType,DocDate,DocDueDate,CardCode,CardName,Address,NumAtCard,DocTotal,DocCurrency,SalesPersonCode,DocTime,Comments,ShipToCode,FederalTaxID,DocumentStatus,Address2,U_RUTA,U_Receta,U_SEI_IDW,U_SEI_FEBOSID),Invoices/DocumentLines($select=LineNum,ItemCode,ItemDescription,Quantity,ShipDate,Price,PriceAfterVAT,WarehouseCode,BarCode,TaxCode)';
    public static String sessionId;

    // Método auxiliar para autenticar y obtener cookie
    private static String authenticateAndGetCookie() {
        System.debug('--- INICIO FacturasCallouts.authenticateAndGetCookie() ---');
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(LOGIN_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(120000);
        
        String requestBody = '{"CompanyDB":"TEST_CMKPROD","UserName":"AVALANCHA","Password":"123456", "Language":25}';
        request.setBody(requestBody);
        
        Http http = new Http();
        HttpResponse response = http.send(request);
        
        System.debug('Auth Status: ' + response.getStatusCode());
        
        if (response.getStatusCode() >= 200 && response.getStatusCode() <= 299) {
            // Extraer cookie B1SESSION del header
            String cookie = extractSessionCookie(response);
            System.debug('Cookie obtenido: ' + cookie);
            return cookie;
        } else {
            System.debug('Error en autenticación: ' + response.getBody());
            return null;
        }
    }
    
    // Método auxiliar para extraer cookie B1SESSION
    private static String extractSessionCookie(HttpResponse response) {
        for (String headerKey : response.getHeaderKeys()) {
            String headerValue = response.getHeader(headerKey);
            if (headerKey.toLowerCase().contains('set-cookie') && headerValue.contains('B1SESSION')) {
                String[] cookieParts = headerValue.split(';');
                for (String part : cookieParts) {
                    if (part.trim().startsWith('B1SESSION=')) {
                        return part.trim();
                    }
                }
                return headerValue;
            }
        }
        return null;
    }

    // Obtener las facturas del cliente
    @future(callout=true)
    public static void getInvoices() {
        System.debug('=== INICIO FacturasCallouts.getInvoices() ===');
        
        // Autenticar y obtener cookie
        String currentCookie = authenticateAndGetCookie();
        
        if (currentCookie == null) {
            System.debug('✗ ERROR: No se pudo obtener cookie de autenticación');
            return;
        }
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(INVOICE_ENDPOINT_TEMPLATE);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setHeader('Cookie', currentCookie);
        request.setTimeout(120000);
        
        System.debug('Endpoint: ' + INVOICE_ENDPOINT_TEMPLATE);
        System.debug('Cookie: ' + currentCookie);

        Http http = new Http();
        HttpResponse response = http.send(request);
        integer responseStatus = response.getStatusCode();
        string responseBody = response.getBody();
        
        System.debug('Response Status: ' + responseStatus);
        System.debug('Response Body: ' + responseBody);
        
        // Limpiar caracteres de control en la respuesta
        responseBody = responseBody.replace('\r', ' ').replace('\n', ' ');
        
        if (responseStatus >= 200 && responseStatus <= 299) {
            System.debug('✓ Facturas obtenidas exitosamente');
            FacturasController.processInvoicesData(responseBody);
        } else {
            System.debug('✗ Error al obtener facturas: ' + responseBody);
        }
        
        System.debug('=== FIN FacturasCallouts.getInvoices() ===');
    }
}