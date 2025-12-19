public class AccountsCallouts {
    private static final String SERVER = label.Clinical_server;
    private static final String PORT = label.Clinical_port;
    private static final String LOGIN_ENDPOINT = SERVER + ':' + PORT + '/b1s/v1/Login';
    private static final String ACCOUNT_ENDPOINT = SERVER + ':' + PORT + '/b1s/v1/BusinessPartners?$select=CardCode,CardName,CardForeignName,CardType,GroupCode,Address,ZipCode,MailAddress,MailZipCode,Phone1,Phone2,Fax,ContactPerson,Notes,PayTermsGrpCode,CreditLimit,MaxCommitment,DiscountPercent,VatLiable,FederalTaxID,PriceListNum,SalesPersonCode,City,County,Country,MailCity,MailCounty,MailCountry,EmailAddress,Valid,Frozen,ShipToDefault,U_SEI_GNRP,CurrentAccountBalance,OpenOrdersBalance,CreateDate,UpdateDate';
    public static String sessionId;
    private static String sessionCookie; // Cookie B1SESSION del servidor

    // Obtener SessionId y cookies
    public static void authenticate() {
        System.debug('=== INICIO AccountsCallouts.authenticate() ===');
        System.debug('LOGIN_ENDPOINT: ' + LOGIN_ENDPOINT);
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(LOGIN_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(120000);

        String requestBody = '{"CompanyDB":"' + Label.BBDD_PROFAR + '","UserName":"' + Label.USUARIO_INT + '","Password":"' + Label.PASS_PROFAR + '", "Language":25}';
        request.setBody(requestBody);
        
        System.debug('Request Body: ' + requestBody);
        System.debug('Timeout: 120000ms');

        Http http = new Http();
        Long startTime = System.currentTimeMillis();
        HttpResponse response = http.send(request);
        Long endTime = System.currentTimeMillis();
        
        System.debug('Auth Response Time: ' + (endTime - startTime) + 'ms');
        System.debug('Auth Status Code: ' + response.getStatusCode());
        System.debug('Auth Response Headers: ' + response.getHeaderKeys());

        if (response.getStatusCode() >= 200 && response.getStatusCode() <= 299) {
            System.debug('✓ Autenticación exitosa');
            
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            sessionId = (String) responseMap.get('SessionId');
            
            // Capturar cookie B1SESSION del servidor
            sessionCookie = extractSessionCookie(response);
            
            System.debug('SessionId obtenido: ' + sessionId);
            System.debug('SessionCookie obtenido: ' + sessionCookie);
            System.debug('✓ authenticate() completado exitosamente');
        } else {
            System.debug('✗ Error en autenticación - Status: ' + response.getStatusCode());
            System.debug('✗ Error Response: ' + response.getBody());
        }
        
        System.debug('=== FIN AccountsCallouts.authenticate() ===');
    }



    // MÉTODO COORDINADOR: Ejecutar integración para ambas bases de datos
    public static void executeAllDatabasesIntegration() {
        System.debug('=== INICIO INTEGRACIÓN MULTI-DATABASE ===');
        System.debug('Ejecutando integraciones en métodos @future separados para evitar conflictos DML+Callout');
        
        // Ejecutar cada integración en su propio contexto @future
        // Esto evita el problema "uncommitted work pending" 
        executeProfarIntegration();
        executeCMKIntegration();
        
        System.debug('✅ Ambas integraciones iniciadas en contextos separados');
        System.debug('=== FIN COORDINADOR INTEGRACIÓN MULTI-DATABASE ===');
    }
    
    // MÉTODO @FUTURE INDEPENDIENTE: Solo Profar
    @future(callout=true)
    public static void executeProfarIntegration() {
        System.debug('=== INICIO INTEGRACIÓN PROFAR [@future] ===');
        try {
            getAccountsForDatabase(Label.BBDD_PROFAR, Label.PASS_PROFAR, 'Profar');
            System.debug('✅ Integración Profar completada');
        } catch (Exception e) {
            System.debug('❌ Error en integración Profar: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
        System.debug('=== FIN INTEGRACIÓN PROFAR ===');
    }
    
    // MÉTODO @FUTURE INDEPENDIENTE: Solo CMK  
    @future(callout=true)
    public static void executeCMKIntegration() {
        System.debug('=== INICIO INTEGRACIÓN CMK [@future] ===');
        try {
            getAccountsForDatabase(Label.BBDD_CMK, Label.PASS_CMK, 'Clientes');
            System.debug('✅ Integración CMK completada');
        } catch (Exception e) {
            System.debug('❌ Error en integración CMK: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
        System.debug('=== FIN INTEGRACIÓN CMK ===');
    }
    
    // MÉTODO PARA MANTENER COMPATIBILIDAD CON VERSIÓN ACTUAL
    @future(callout=true)
    public static void getAccounts() {
        System.debug('=== LLAMADA LEGACY getAccounts() - Usando configuración Profar ===');
        getAccountsForDatabase(Label.BBDD_PROFAR, Label.PASS_PROFAR, 'Profar');
    }
    
    // MÉTODO INTERNO: Obtener cuentas para una base de datos específica
    private static void getAccountsForDatabase(String companyDB, String password, String recordTypeName) {
        System.debug('=== INICIO getAccountsForDatabase() ===');
        System.debug('CompanyDB: ' + companyDB);
        System.debug('RecordType: ' + recordTypeName);
        System.debug('ACCOUNT_ENDPOINT: ' + ACCOUNT_ENDPOINT);
        
        // Autenticar y obtener cookie para esta base de datos específica
        System.debug('--- PASO 1: Autenticación ---');
        String currentCookie = authenticateAndGetCookie(companyDB, password);
        
        if (currentCookie == null) {
            System.debug('✗ ERROR CRÍTICO: No se pudo obtener cookie de autenticación para ' + companyDB);
            System.debug('=== FIN getAccountsForDatabase() [ERROR] ===');
            return;
        }
        
        System.debug('✓ Cookie obtenido: ' + currentCookie);
        
        // Preparar llamada de cuentas
        System.debug('--- PASO 2: Llamada de Cuentas ---');
        HttpRequest request = new HttpRequest();
        request.setEndpoint(ACCOUNT_ENDPOINT);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setHeader('Cookie', currentCookie); // Usar cookie en lugar de header B1SESSION
        request.setTimeout(120000);
        
        System.debug('Request Headers configurados: Cookie, Content-Type, Accept');
        System.debug('Timeout: 120000ms');

        Http http = new Http();
        Long startTime = System.currentTimeMillis();
        HttpResponse response = http.send(request);
        Long endTime = System.currentTimeMillis();
        
        integer responseStatus = response.getStatusCode();
        string responseBody = response.getBody();
        
        System.debug('Accounts Response Time: ' + (endTime - startTime) + 'ms');
        System.debug('Accounts Status Code: ' + responseStatus);
        System.debug('Accounts Response Headers: ' + response.getHeaderKeys());
        
        if (responseStatus >= 200 && responseStatus <= 299) {
            System.debug('✓ Cuentas obtenidas exitosamente');
            System.debug('Response Body Length: ' + responseBody.length() + ' caracteres');
            
            // Mostrar primeros 500 caracteres para debug
            String preview = responseBody.length() > 500 ? responseBody.substring(0, 500) + '...' : responseBody;
            System.debug('Response Preview: ' + preview);
            
            // Procesar datos con Record Type específico
            System.debug('--- PASO 3: Procesamiento de Datos ---');
            try {
                AccountsController.processAccountData(responseBody, recordTypeName);
                System.debug('✓ Datos procesados exitosamente con RecordType: ' + recordTypeName);
            } catch (Exception e) {
                System.debug('✗ ERROR procesando datos: ' + e.getMessage());
                System.debug('✗ Stack Trace: ' + e.getStackTraceString());
            }
        } else {
            System.debug('✗ ERROR al obtener cuentas');
            System.debug('✗ Status Code: ' + responseStatus);
            System.debug('✗ Response Body: ' + responseBody);
        }
        
        System.debug('=== FIN getAccountsForDatabase() ===');
    }
    
    // MÉTODO AUXILIAR: Autenticar y obtener cookie con parámetros específicos
    private static String authenticateAndGetCookie(String companyDB, String password) {
        System.debug('--- INICIO authenticateAndGetCookie() ---');
        System.debug('CompanyDB: ' + companyDB);
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(LOGIN_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setTimeout(120000);
        
        String requestBody = '{"CompanyDB":"' + companyDB + '","UserName":"' + Label.USUARIO_INT + '","Password":"' + password + '", "Language":25}';
        request.setBody(requestBody);
        
        System.debug('Auth Request configurado - Endpoint: ' + LOGIN_ENDPOINT);
        System.debug('Auth Request Body: ' + requestBody);
        
        Http http = new Http();
        Long startTime = System.currentTimeMillis();
        HttpResponse response = http.send(request);
        Long endTime = System.currentTimeMillis();
        
        System.debug('Auth Response Time: ' + (endTime - startTime) + 'ms');
        System.debug('Auth Status Code: ' + response.getStatusCode());
        
        if (response.getStatusCode() >= 200 && response.getStatusCode() <= 299) {
            System.debug('✓ Autenticación exitosa para ' + companyDB);
            
            // Extraer SessionId del body
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            sessionId = (String) responseMap.get('SessionId');
            
            // Extraer cookie B1SESSION del header
            String cookie = extractSessionCookie(response);
            
            System.debug('SessionId extraído: ' + sessionId);
            System.debug('Cookie extraído: ' + cookie);
            
            if (cookie != null) {
                System.debug('✓ Cookie obtenido exitosamente');
                System.debug('--- FIN authenticateAndGetCookie() [SUCCESS] ---');
                return cookie;
            } else {
                System.debug('✗ ERROR: No se pudo extraer cookie B1SESSION');
                System.debug('--- FIN authenticateAndGetCookie() [ERROR] ---');
                return null;
            }
        } else {
            System.debug('✗ ERROR en autenticación - Status: ' + response.getStatusCode());
            System.debug('✗ Error Response: ' + response.getBody());
            System.debug('--- FIN authenticateAndGetCookie() [ERROR] ---');
            return null;
        }
    }
    
    // MÉTODO LEGACY: Para mantener compatibilidad
    private static String authenticateAndGetCookie() {
        return authenticateAndGetCookie(Label.BBDD_PROFAR, Label.PASS_PROFAR);
    }
    
    // Método auxiliar para extraer cookie B1SESSION de la respuesta
    private static String extractSessionCookie(HttpResponse response) {
        System.debug('--- INICIO extractSessionCookie() ---');
        System.debug('Response Headers disponibles: ' + response.getHeaderKeys());
        
        for (String headerKey : response.getHeaderKeys()) {
            String headerValue = response.getHeader(headerKey);
            System.debug('Procesando header: ' + headerKey + ' = ' + headerValue);
            
            // Buscar header Set-Cookie que contenga B1SESSION
            if (headerKey.toLowerCase().contains('set-cookie') && headerValue.contains('B1SESSION')) {
                System.debug('✓ Header Set-Cookie con B1SESSION encontrado');
                System.debug('Header completo: ' + headerValue);
                
                // Extraer solo la parte del cookie que necesitamos
                String[] cookieParts = headerValue.split(';');
                System.debug('Cookie parts: ' + cookieParts.size());
                
                for (String part : cookieParts) {
                    System.debug('Procesando cookie part: ' + part.trim());
                    if (part.trim().startsWith('B1SESSION=')) {
                        String extractedCookie = part.trim();
                        System.debug('✓ Cookie B1SESSION extraído: ' + extractedCookie);
                        System.debug('--- FIN extractSessionCookie() [SUCCESS] ---');
                        return extractedCookie;
                    }
                }
                
                // Si no encontramos el formato esperado, devolver el header completo
                System.debug('⚠ No se encontró formato B1SESSION=, devolviendo header completo');
                System.debug('--- FIN extractSessionCookie() [FALLBACK] ---');
                return headerValue;
            }
        }
        
        System.debug('✗ No se encontró cookie B1SESSION en los headers');
        System.debug('--- FIN extractSessionCookie() [NOT FOUND] ---');
        return null;
    }
}