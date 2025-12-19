/**
 * @description Clase para realizar callouts a la API de SAP B1 para obtener direcciones de Socios de Negocio.
 * Sigue un patrón de integración multi-database, con métodos separados para cada base de datos (PROFAR y CMK).
 */
public with sharing class DireccionesCallouts {
  private static final String SERVER = label.Clinical_server;
  private static final String PORT = label.Clinical_port;
  private static final String LOGIN_ENDPOINT =
    SERVER +
    ':' +
    PORT +
    '/b1s/v1/Login';
  private static final String BASE_URL = '/b1s/v1/$crossjoin(BusinessPartners,BusinessPartners/BPAddresses)';
  private static final String EXPAND_VALUE = 'BusinessPartners/BPAddresses($select=AddressName,Street,City,County,State,AddressType)';
  public static String sessionId;

  /**
   * @description Método coordinador que inicia la sincronización de direcciones para todas las bases de datos configuradas.
   * Llama a los métodos @future de forma separada para evitar conflictos y límites de gobernador.
   */
  public static void executeAllDatabasesIntegration() {
    executeProfarAddressIntegration();
    executeCMKAddressIntegration();
  }

  /**
   * @description Método asíncrono (@future) para ejecutar la integración de direcciones para la base de datos PROFAR.
   */
  @future(callout=true)
  public static void executeProfarAddressIntegration() {
    System.debug('=== INICIO DIRECCIONES INTEGRACIÓN PROFAR [@future] ===');
    try {
      getAddressesForDatabase(Label.BBDD_PROFAR, Label.PASS_PROFAR, 'Profar');
      System.debug('✅ Integración de direcciones Profar completada');
    } catch (Exception e) {
      System.debug(
        '❌ Error en integración de direcciones Profar: ' + e.getMessage()
      );
      System.debug('Stack Trace: ' + e.getStackTraceString());
    }
    System.debug('=== FIN DIRECCIONES INTEGRACIÓN PROFAR ===');
  }

  /**
   * @description Método asíncrono (@future) para ejecutar la integración de direcciones para la base de datos CMK.
   */
  @future(callout=true)
  public static void executeCMKAddressIntegration() {
    System.debug('=== INICIO DIRECCIONES INTEGRACIÓN CMK [@future] ===');
    try {
      getAddressesForDatabase(Label.BBDD_CMK, Label.PASS_CMK, 'Clientes');
      System.debug('✅ Integración de direcciones CMK completada');
    } catch (Exception e) {
      System.debug(
        '❌ Error en integración de direcciones CMK: ' + e.getMessage()
      );
      System.debug('Stack Trace: ' + e.getStackTraceString());
    }
    System.debug('=== FIN DIRECCIONES INTEGRACIÓN CMK ===');
  }

  /**
   * @description Obtiene y procesa las direcciones para todas las cuentas de un tipo de registro y base de datos específicos.
   * @param companyDB El nombre de la base de datos de la compañía en SAP.
   * @param password La contraseña para la autenticación en SAP.
   * @param recordTypeName El nombre del tipo de registro de las cuentas a procesar.
   */
  private static void getAddressesForDatabase(
    String companyDB,
    String password,
    String recordTypeName
  ) {
    String currentCookie = authenticateAndGetCookie(companyDB, password);
    if (currentCookie == null) {
      return;
    }

    List<Account> accounts = getAccountsToProcess(recordTypeName);
    List<Direcciones__c> allAddressesToUpdate = new List<Direcciones__c>();

    for (Account acc : accounts) {
      try {
        HttpResponse response = performCallout(
          acc.C_digo_socio_negocios__c,
          currentCookie
        );
        if (
          response.getStatusCode() >= 200 &&
          response.getStatusCode() <= 299
        ) {
          //System.debug('Direcciones obtenidas correctamente para CardCode: ' + acc.C_digo_socio_negocios__c);
          allAddressesToUpdate.addAll(
            DireccionesController.processAddressData(
              response.getBody(),
              acc.C_digo_socio_negocios__c
            )
          );
        }
      } catch (Exception e) {
        System.debug(
          'Error procesando cuenta ' + acc.Id + ': ' + e.getMessage()
        );
      }
    }

    upsertAddresses(allAddressesToUpdate);
    System.debug(
      'Total de direcciones procesadas para ' +
      recordTypeName +
      ': ' +
      allAddressesToUpdate.size()
    );
  }

  /**
   * @description Retorna la lista de cuentas a procesar para un tipo de registro específico.
   * @param recordTypeName El nombre del tipo de registro.
   * @return La lista de Cuentas.
   */
  private static List<Account> getAccountsToProcess(String recordTypeName) {
    Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName()
      .get(recordTypeName)
      .getRecordTypeId();
    return [
      SELECT Id, C_digo_socio_negocios__c
      FROM Account
      WHERE RecordTypeId = :rtId AND C_digo_socio_negocios__c != NULL
      WITH SYSTEM_MODE
    ];
  }

  /**
   * @description Realiza el callout a la API de SAP para obtener las direcciones de un socio de negocio.
   * @param cardCode El código del socio de negocio.
   * @param cookie Las cookies de sesión.
   * @return La respuesta HTTP.
   */
  private static HttpResponse performCallout(String cardCode, String cookie) {
    String filterValue =
      'BusinessPartners/CardCode eq BusinessPartners/BPAddresses/BPCode and BusinessPartners/CardCode eq \'' +
      cardCode +
      '\'';
    String encodedExpand = EncodingUtil.urlEncode(EXPAND_VALUE, 'UTF-8');
    String encodedFilter = EncodingUtil.urlEncode(filterValue, 'UTF-8');
    String endpoint =
      SERVER +
      ':' +
      PORT +
      BASE_URL +
      '?$expand=' +
      encodedExpand +
      '&$filter=' +
      encodedFilter;

    HttpRequest request = new HttpRequest();
    request.setEndpoint(endpoint);
    request.setMethod('GET');
    request.setHeader('Content-Type', 'application/json');
    request.setHeader('Accept', 'application/json');
    request.setHeader('Cookie', cookie);
    request.setHeader('User-Agent', 'Apex-Callout');
    request.setTimeout(120000);

    Http http = new Http();
    return http.send(request);
  }

  /**
   * @description Realiza el upsert de la lista de direcciones y maneja los permisos FLS.
   * @param addresses La lista de direcciones a insertar/actualizar.
   */
  private static void upsertAddresses(List<Direcciones__c> addresses) {
    try {
      if (
        Schema.sObjectType.Direcciones__c.isUpdateable() &&
        Schema.sObjectType.Direcciones__c.isCreateable()
      ) {
        upsert addresses ID_Externo_Direcciones__c;
      }
      //   else {
      //     System.debug('Error de FLS: Faltan permisos para actualizar el objeto o campos de Direcciones__c.');
      //   }
    } catch (DmlException e) {
      System.debug('Error al actualizar las direcciones: ' + e.getMessage());
    }
  }

  /**
   * @description Autentica contra la API de SAP y retorna las cookies de sesión.
   * @param companyDB El nombre de la base de datos de la compañía en SAP.
   * @param password La contraseña para la autenticación.
   * @return Un string con las cookies de sesión, o null si la autenticación falla.
   */
  private static String authenticateAndGetCookie(
    String companyDB,
    String password
  ) {
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
      return extractSessionCookies(response);
    }
    System.debug(
      'ERROR: No se pudo autenticar. Status: ' +
      response.getStatusCode() +
      ' - Body: ' +
      response.getBody()
    );
    return null;
  }

  /**
   * @description Extrae y concatena todas las cookies de la respuesta HTTP.
   * @param response La respuesta HTTP del callout.
   * @return Un string que contiene todas las cookies separadas por punto y coma.
   */
  private static String extractSessionCookies(HttpResponse response) {
    String cookieHeader = response.getHeader('Set-Cookie');
    if (String.isNotBlank(cookieHeader)) {
      List<String> cookies = new List<String>();
      List<String> separateCookies = cookieHeader.split(',');
      for (String singleCookie : separateCookies) {
        if (String.isNotBlank(singleCookie)) {
          cookies.add(singleCookie.split(';')[0].trim());
        }
      }
      return String.join(cookies, '; ');
    }
    return null;
  }
}