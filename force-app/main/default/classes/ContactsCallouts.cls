public class ContactsCallouts {
    private static final String SERVER = label.Clinical_server;
    private static final String PORT = label.Clinical_port;
    private static final String LOGIN_ENDPOINT = SERVER + ':' + PORT + '/b1s/v1/Login';
    private static final String CONTACT_ENDPOINT = SERVER + ':' + PORT + '/b1s/v1/$crossjoin(BusinessPartners,BusinessPartners/ContactEmployees)?$expand=BusinessPartners($select=CardCode,CardName),BusinessPartners/ContactEmployees($select=Name,FirstName,E_Mail,MobilePhone)';
    public static String sessionId;
    private static String sessionCookie;

    // MÉTODO COORDINADOR: Ejecutar integración para ambas bases de datos
    public static void executeAllDatabasesIntegration() {
        executeProfarIntegration();
        executeCMKIntegration();
    }
    
    // MÉTODO @FUTURE INDEPENDIENTE: Solo Profar
    @future(callout=true)
    public static void executeProfarIntegration() {
        try {
            getContactsForDatabase(Label.BBDD_PROFAR, Label.PASS_PROFAR);
        } catch (Exception e) {
            System.debug('Error en integración Contacts Profar: ' + e.getMessage());
        }
    }
    
    // MÉTODO @FUTURE INDEPENDIENTE: Solo CMK
    @future(callout=true)
    public static void executeCMKIntegration() {
        try {
            getContactsForDatabase(Label.BBDD_CMK, Label.PASS_CMK);
        } catch (Exception e) {
            System.debug('Error en integración Contacts CMK: ' + e.getMessage());
        }
    }
    
    // MÉTODO LEGACY: Para mantener compatibilidad
    @future(callout=true)
    public static void getContacts() {
        getContactsForDatabase(Label.BBDD_PROFAR, Label.PASS_PROFAR);
    }
    
    // MÉTODO INTERNO: Obtener contactos para una base de datos específica
    private static void getContactsForDatabase(String companyDB, String password) {
        String currentCookie = authenticateAndGetCookie(companyDB, password);
        
        if (currentCookie == null) {
            System.debug('ERROR: No se pudo obtener cookie de autenticación');
            return;
        }
        
        HttpRequest request = new HttpRequest();
        request.setEndpoint(CONTACT_ENDPOINT);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setHeader('Cookie', currentCookie);
        request.setTimeout(120000);

        Http http = new Http();
        HttpResponse response = http.send(request);
        Integer responseStatus = response.getStatusCode();
        String responseBody = response.getBody();
        
        if (responseStatus >= 200 && responseStatus <= 299) {
            try {
                ContactsController.processContactData(responseBody);
            } catch (Exception e) {
                System.debug('ERROR procesando datos: ' + e.getMessage());
            }
        } else {
            System.debug('ERROR al obtener contactos - Status: ' + responseStatus);
        }
    }
    
    // MÉTODO AUXILIAR: Autenticar y obtener cookie
    private static String authenticateAndGetCookie(String companyDB, String password) {
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
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            sessionId = (String) responseMap.get('SessionId');
            return extractSessionCookie(response);
        }
        return null;
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
}