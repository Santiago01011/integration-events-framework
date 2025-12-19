public class ProductosCallouts {
    private static final String SERVER = label.Clinical_server;
    private static final String PORT = label.Clinical_port;
    private static final String LOGIN_ENDPOINT = SERVER + ':' + PORT + '/b1s/v1/Login';
    public static String sessionId;

    private static String authenticateAndGetCookie(String companyDB, String password) {
        System.debug('--- INICIO ProductosCallouts.authenticateAndGetCookie() ---');
        
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
        
        if (response.getStatusCode() >= 200 && response.getStatusCode() <= 299) {
            String cookie = extractSessionCookie(response);
            System.debug('Auth Status: ' + response.getStatusCode() + ' Cookie obtenido: ' + cookie);
            return cookie;
        } else {
            System.debug('Error en autenticación: ' + response.getBody() + ' Auth Status: ' + response.getStatusCode());
            return null;
        }
    }
    
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
     * @description Obtiene los productos de la base de datos para un cliente específico.
     * @param companyDB Nombre de la base de datos.
     * @param password Contraseña para autenticación.
     */
    private static void getProductsForDatabase(String companyDB, String password) {
        System.debug('=== INICIO ProductosCallouts.getProductsForDatabase() ===');
        
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
        ProductosController.processProductData(combinedJson);
        
        System.debug('=== FIN ProductosCallouts.getProductsForDatabase() ===');
    }

    /**
     * @description Construye el endpoint inicial para la consulta OData.
     * @return URL completa del endpoint inicial.
     */
    private static String buildInitialEndpoint() {
        String baseUrl = SERVER + ':' + PORT + '/b1s/v1/$crossjoin(Items,Manufacturers,ItemGroups)';
        String expandValue = 'Manufacturers($select=ManufacturerName),Items($select=ItemCode,UpdateDate,ItemName,U_SEI_PA,U_SEI_GEN,U_SEI_ROT,U_Departamento,U_Categoria,U_SubCategoria,Valid,BarCode,U_SEI_FAM,U_SEI_SUBFAM,Mainsupplier,DefaultWarehouse),ItemGroups($select=GroupName)';
        String filterValue = 'Items/Manufacturer eq Manufacturers/Code and Items/ItemsGroupCode eq ItemGroups/Number and Items/Valid eq \'Y\' and Items/UpdateDate gt \'2025-08-01\'';
        String encodedExpand = EncodingUtil.urlEncode(expandValue, 'UTF-8');
        String encodedFilter = EncodingUtil.urlEncode(filterValue, 'UTF-8');
        return baseUrl + '?$expand=' + encodedExpand + '&$filter=' + encodedFilter;
    }

    /**
     * @description Procesa una página individual: hace la request, parsea y acumula datos.
     * @param endpoint URL de la página actual.
     * @param cookie Cookie de sesión.
     * @param allValues Lista acumulativa de productos (pasada por referencia).
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
            System.debug('Page ' + pageCount + ' productos obtenidos exitosamente');
            
            // Parse response and accumulate values
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            List<Object> pageValues = (List<Object>) jsonResponse.get('value');
            if (pageValues != null) {
                allValues.addAll(pageValues);
                System.debug('Added ' + pageValues.size() + ' products from page ' + pageCount + '. Total so far: ' + allValues.size());
            }
            
            // Check for nextLink
            String nextLink = (String) jsonResponse.get('odata.nextLink');
            if (String.isNotBlank(nextLink)) {
                // nextLink is relative, prefix with base URL
                return SERVER + ':' + PORT + '/b1s/v1/' + nextLink;
            } else {
                System.debug('No more pages.');
                return null;
            }
        } else {
            System.debug('Error en page ' + pageCount + ': ' + responseBody);
            return null; // Stop on error
        }
    }

    /**
     * @description Registra un resumen de la sincronización para una base de datos.
     * @param companyDB Nombre de la base de datos.
     * @param pageCount Número total de páginas procesadas.
     * @param totalProducts Número total de productos acumulados.
     */
    private static void logSummary(String companyDB, Integer pageCount, Integer totalProducts) {
        System.debug('SUMMARY: DB=' + companyDB + ', Pages=' + pageCount + ', Products=' + totalProducts);
    }

    /**
     * @description Método coordinador que inicia la sincronización de productos para todas las bases de datos configuradas.
     * Llama a los métodos @future de forma separada para evitar conflictos y límites de gobernador.
     */
    public static void executeAllDatabasesProductIntegration() {
        executeProfarProductIntegration();
        executeCMKProductIntegration();
    }

    /**
     * @description Método asíncrono (@future) para ejecutar la integración de productos para la base de datos PROFAR.
     */
    @future(callout=true)
    public static void executeProfarProductIntegration() {
        System.debug('=== INICIO PRODUCTOS INTEGRACIÓN PROFAR [@future] ===');
        try {
            getProductsForDatabase(Label.BBDD_PROFAR, Label.PASS_PROFAR);
            System.debug('✅ Integración de productos Profar completada');
        } catch (Exception e) {
            System.debug('❌ Error en integración de productos Profar: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
        System.debug('=== FIN PRODUCTOS INTEGRACIÓN PROFAR ===');
    }

    /**
     * @description Método asíncrono (@future) para ejecutar la integración de productos para la base de datos CMK.
     */
    @future(callout=true)
    public static void executeCMKProductIntegration() {
        System.debug('=== INICIO PRODUCTOS INTEGRACIÓN CMK [@future] ===');
        try {
            getProductsForDatabase(Label.BBDD_CMK, Label.PASS_CMK);
            System.debug('✅ Integración de productos CMK completada');
        } catch (Exception e) {
            System.debug('❌ Error en integración de productos CMK: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
        System.debug('=== FIN PRODUCTOS INTEGRACIÓN CMK ===');
    }
}