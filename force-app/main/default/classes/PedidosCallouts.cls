public class PedidosCallouts {
    private static final String SERVER = label.Clinical_server;
    private static final String PORT = label.Clinical_port;
    private static final String LOGIN_ENDPOINT = SERVER + ':' + PORT + '/b1s/v1/Login';
    public static String sessionId;

    // Método auxiliar para autenticar y obtener cookie
    private static String authenticateAndGetCookie(String companyDB, String password) {
        System.debug('--- INICIO PedidosCallouts.authenticateAndGetCookie() ---');
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(LOGIN_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(120000);
        
        String requestBody = '{"CompanyDB":"' + companyDB + '","UserName":"' + Label.USUARIO_INT + '","Password":"' + password + '", "Language":25}';
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

    /**
     * @description Construye el endpoint inicial para la consulta OData de pedidos.
     * @return URL completa del endpoint inicial.
     */
    private static String buildInitialEndpoint() {
        String baseUrl = SERVER + ':' + PORT + '/b1s/v1/$crossjoin(Orders,Orders/DocumentLines)';
        String expandValue = 'Orders($select=DocEntry,DocNum,DocType,DocDate,DocDueDate,CardCode,CardName,Address,NumAtCard,DocTotal,DocCurrency,SalesPersonCode,DocTime,Comments,ShipToCode,FederalTaxID,DocumentStatus,Address2,U_Receta,U_SEI_IDW),Orders/DocumentLines($select=LineNum,ItemCode,ItemDescription,Quantity,ShipDate,Price,PriceAfterVAT,WarehouseCode,BarCode,TaxCode)';
        String filterValue = 'Orders/DocEntry eq Orders/DocumentLines/DocEntry';
        String encodedExpand = EncodingUtil.urlEncode(expandValue, 'UTF-8');
        String encodedFilter = EncodingUtil.urlEncode(filterValue, 'UTF-8');
        return baseUrl + '?$expand=' + encodedExpand + '&$filter=' + encodedFilter;
    }

    /**
     * @description Obtiene los pedidos de la base de datos para un cliente específico.
     * @param companyDB Nombre de la base de datos.
     * @param password Contraseña para autenticación.
     */
    private static void getOrdersForDatabase(String companyDB, String password) {
        System.debug('=== INICIO PedidosCallouts.getOrdersForDatabase() ===');
        
        String currentCookie = authenticateAndGetCookie(companyDB, password);
        
        if (currentCookie == null) {
            System.debug('✗ ERROR: No se pudo obtener cookie de autenticación');
            return;
        }
        
        String currentEndpoint = buildInitialEndpoint();
        List<Object> allValues = new List<Object>();
        Integer pageCount = 0;
        final Integer maxPages = 5;
        
        while (currentEndpoint != null && pageCount < maxPages) {
            pageCount++;
            currentEndpoint = processPage(currentEndpoint, currentCookie, allValues, pageCount);
        }
        
        logSummary(companyDB, pageCount, allValues.size());
        
        Map<String, Object> combinedResponse = new Map<String, Object>();
        combinedResponse.put('value', allValues);
        String combinedJson = JSON.serialize(combinedResponse);
        
        // Process all accumulated data
        PedidosController.processOrdersData(combinedJson);
        
        System.debug('=== FIN PedidosCallouts.getOrdersForDatabase() ===');
    }

    /**
     * @description Procesa una página individual: hace la request, parsea y acumula datos.
     * @param endpoint URL de la página actual.
     * @param cookie Cookie de sesión.
     * @param allValues Lista acumulativa de pedidos (pasada por referencia).
     * @param pageCount Número de página actual.
     * @return Siguiente endpoint o null si no hay más páginas.
     */
    private static String processPage(String endpoint, String cookie, List<Object> allValues, Integer pageCount) {
        System.debug('Processing page ' + pageCount + ' with endpoint: ' + endpoint);
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setHeader('Cookie', cookie);
        request.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse response = http.send(request);
        Integer responseStatus = response.getStatusCode();
        String responseBody = response.getBody();
        
        System.debug('Page ' + pageCount + ' Response Status: ' + responseStatus);
        
        if (responseStatus >= 200 && responseStatus <= 299) {
            System.debug('Page ' + pageCount + ' pedidos obtenidos exitosamente');
            
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> pageValues = (List<Object>) jsonResponse.get('value');
            if (pageValues != null) {
                allValues.addAll(pageValues);
                System.debug('Added ' + pageValues.size() + ' orders from page ' + pageCount + '. Total so far: ' + allValues.size());
            }
            
            String nextLink = (String) jsonResponse.get('odata.nextLink');
            if (String.isNotBlank(nextLink)) {
                return SERVER + ':' + PORT + '/b1s/v1/' + nextLink;
            } else {
                System.debug('No more pages.');
                return null;
            }
        } else {
            System.debug('Error en page ' + pageCount + ': ' + responseBody);
            return null;
        }
    }

    /**
     * @description Registra un resumen de la sincronización para una base de datos.
     * @param companyDB Nombre de la base de datos.
     * @param pageCount Número total de páginas procesadas.
     * @param totalOrders Número total de pedidos acumulados.
     */
    private static void logSummary(String companyDB, Integer pageCount, Integer totalOrders) {
        System.debug('SUMMARY: DB=' + companyDB + ', Pages=' + pageCount + ', Orders=' + totalOrders);
    }

    /**
     * @description Método coordinador que inicia la sincronización de pedidos para todas las bases de datos configuradas.
     * Llama a los métodos @future de forma separada para evitar conflictos y límites de gobernador.
     */
    public static void executeAllDatabasesOrderIntegration() {
        executeProfarOrderIntegration();
        executeCMKOrderIntegration();
    }

    /**
     * @description Método asíncrono (@future) para ejecutar la integración de pedidos para la base de datos PROFAR.
     */
    @future(callout=true)
    public static void executeProfarOrderIntegration() {
        System.debug('=== INICIO PEDIDOS INTEGRACIÓN PROFAR [@future] ===');
        try {
            getOrdersForDatabase(Label.BBDD_PROFAR, Label.PASS_PROFAR);
            System.debug('✅ Integración de pedidos Profar completada');
        } catch (Exception e) {
            System.debug('❌ Error en integración de pedidos Profar: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
        System.debug('=== FIN PEDIDOS INTEGRACIÓN PROFAR ===');
    }

    /**
     * @description Método asíncrono (@future) para ejecutar la integración de pedidos para la base de datos CMK.
     */
    @future(callout=true)
    public static void executeCMKOrderIntegration() {
        System.debug('=== INICIO PEDIDOS INTEGRACIÓN CMK [@future] ===');
        try {
            getOrdersForDatabase(Label.BBDD_CMK, Label.PASS_CMK);
            System.debug('✅ Integración de pedidos CMK completada');
        } catch (Exception e) {
            System.debug('❌ Error en integración de pedidos CMK: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
        System.debug('=== FIN PEDIDOS INTEGRACIÓN CMK ===');
    }
}