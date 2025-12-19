/**
 * @description Test class para DireccionesCallouts siguiendo best practices
 */
@isTest
private class DireccionesCalloutsTest {
  /**
   * @description Configuración de datos de prueba
   */
  @TestSetup
  static void makeData() {
    // Obtener Record Types existentes (no crear nuevos en tests)
    Id profarRtId = Schema.SObjectType.Account.getRecordTypeInfosByName()
      .get('Profar')
      .getRecordTypeId();
    Id clientesRtId = Schema.SObjectType.Account.getRecordTypeInfosByName()
      .get('Clientes')
      .getRecordTypeId();

    // Crear Account de prueba Profar
    Account testProfarAccount = new Account(
      Name = 'Test Profar Account',
      RecordTypeId = profarRtId,
      C_digo_socio_negocios__c = 'PROF001'
    );
    insert testProfarAccount;

    // Crear Account de prueba Clientes
    Account testClientesAccount = new Account(
      Name = 'Test Clientes Account',
      RecordTypeId = clientesRtId,
      C_digo_socio_negocios__c = 'CLIENT001'
    );
    insert testClientesAccount;
  }

  /**
   * @description Prueba integración exitosa en ambas bases de datos
   */
  @isTest
  static void testExecuteAllDatabasesIntegrationSuccess() {
    // Configurar mock para simular respuestas exitosas de ambas bases de datos
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(true, true)
    );

    // Crear usuario de prueba para runAs
    User testUser = createTestUser();

    Test.startTest();
    System.runAs(testUser) {
      DireccionesCallouts.executeAllDatabasesIntegration();
    }
    Test.stopTest();

    // Verificar que se crearon 4 direcciones (2 por cada account)
    List<Direcciones__c> direcciones = [
      SELECT Id, Name, ID_Externo_Direcciones__c, Account__c
      FROM Direcciones__c
    ];
    Assert.areEqual(
      4,
      direcciones.size(),
      'Debería crear 4 direcciones para una ejecución exitosa completa'
    );

    // Verificar que las direcciones tienen External IDs válidos
    for (Direcciones__c dir : direcciones) {
      Assert.isNotNull(
        dir.ID_Externo_Direcciones__c,
        'External ID no debe ser null'
      );
      Assert.isTrue(
        dir.ID_Externo_Direcciones__c.contains('-'),
        'External ID debe contener formato AccountId-Name-Type'
      );
    }
  }

  /**
   * @description Prueba fallo de autenticación
   */
  @isTest
  static void testAuthenticationFailure() {
    // Configurar mock para simular fallo de autenticación
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(false, false)
    );

    // Crear usuario de prueba para runAs
    User testUser = createTestUser();

    Test.startTest();
    System.runAs(testUser) {
      DireccionesCallouts.executeAllDatabasesIntegration();
    }
    Test.stopTest();

    // Verificar que no se crearon direcciones
    List<Direcciones__c> direcciones = [SELECT Id FROM Direcciones__c];
    Assert.areEqual(
      0,
      direcciones.size(),
      'No debería crear direcciones si falla la autenticación'
    );
  }

  /**
   * @description Prueba éxito parcial (una BD exitosa, otra falla)
   */
  @isTest
  static void testPartialSuccess() {
    // Configurar mock para simular éxito en una BD y fallo en otra
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(true, false)
    );

    // Crear usuario de prueba para runAs
    User testUser = createTestUser();

    Test.startTest();
    System.runAs(testUser) {
      DireccionesCallouts.executeAllDatabasesIntegration();
    }
    Test.stopTest();

    // Verificar que solo se crearon 2 direcciones para la integración exitosa
    List<Direcciones__c> direcciones = [
      SELECT Id, Account__r.RecordType.Name
      FROM Direcciones__c
    ];
    Assert.areEqual(
      2,
      direcciones.size(),
      'Debería crear direcciones solo para la integración exitosa de BD'
    );

    // Verificar que todas las direcciones son del RecordType Profar (exitoso)
    for (Direcciones__c dir : direcciones) {
      Assert.areEqual(
        'Profar',
        dir.Account__r.RecordType.Name,
        'Direcciones deben pertenecer solo a accounts Profar'
      );
    }
  }

  /**
   * @description Método helper para crear usuario de prueba
   * @return Usuario de prueba configurado
   */
  private static User createTestUser() {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];

    User testUser = new User(
      Alias = 'testUsr',
      Email = 'test@direcciones.test',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Test',
      LastName = 'User',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'test.direcciones.user@test.com'
    );
    insert testUser;
    return testUser;
  }

  /**
   * @description Generador genérico de respuestas mock HTTP
   */
  public class MockHttpResponseGenerator implements HttpCalloutMock {
    private boolean profarAuthSuccess;
    private boolean cmkAuthSuccess;

    public MockHttpResponseGenerator(
      boolean profarAuthSuccess,
      boolean cmkAuthSuccess
    ) {
      this.profarAuthSuccess = profarAuthSuccess;
      this.cmkAuthSuccess = cmkAuthSuccess;
    }

    public HTTPResponse respond(HTTPRequest req) {
      String endpoint = req.getEndpoint();
      String requestBody = req.getBody();

      if (endpoint.contains('/Login')) {
        if (requestBody.contains(Label.BBDD_PROFAR)) {
          return createAuthResponse(profarAuthSuccess);
        } else if (requestBody.contains(Label.BBDD_CMK)) {
          return createAuthResponse(cmkAuthSuccess);
        }
      } else if (endpoint.contains('/crossjoin')) {
        return createDataResponse();
      }

      // Default response for unexpected calls
      return createErrorResponse(404, 'Endpoint not mocked');
    }

    /**
     * @description Crear respuesta de autenticación mock
     * @param success Si la autenticación debe ser exitosa
     * @return Respuesta HTTP mock
     */
    private HTTPResponse createAuthResponse(boolean success) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (success) {
        res.setHeader(
          'Set-Cookie',
          'B1SESSION=test-session-id-12345; Path=/; Secure'
        );
        res.setBody(
          '{"SessionId": "test-session-id-12345", "Version": "10.0"}'
        );
        res.setStatusCode(200);
      } else {
        res.setBody(
          '{"error": {"code": -304, "message": {"lang": "en-us", "value": "Authentication Failed"}}}'
        );
        res.setStatusCode(401);
      }
      return res;
    }

    /**
     * @description Crear respuesta de datos de direcciones mock
     * @return Respuesta HTTP mock con datos de direcciones
     */
    private HttpResponse createDataResponse() {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      String responseBody =
        '{\n' +
        '  "odata.metadata": "$metadata#Collection(Edm.ComplexType)",\n' +
        '  "value": [\n' +
        '    {\n' +
        '      "BusinessPartners/BPAddresses": {\n' +
        '        "AddressName": "Test Billing Address",\n' +
        '        "Street": "123 Test Street",\n' +
        '        "City": "Test City",\n' +
        '        "County": "Test County",\n' +
        '        "State": "13",\n' +
        '        "AddressType": "B"\n' +
        '      }\n' +
        '    },\n' +
        '    {\n' +
        '      "BusinessPartners/BPAddresses": {\n' +
        '        "AddressName": "Test Shipping Address",\n' +
        '        "Street": "456 Ship Avenue",\n' +
        '        "City": "Ship City",\n' +
        '        "County": "Ship County",\n' +
        '        "State": "13",\n' +
        '        "AddressType": "S"\n' +
        '      }\n' +
        '    }\n' +
        '  ]\n' +
        '}';

      res.setBody(responseBody);
      res.setStatusCode(200);
      return res;
    }

    /**
     * @description Crear respuesta de error mock
     * @param statusCode Código de estado HTTP
     * @param message Mensaje de error
     * @return Respuesta HTTP de error
     */
    private HTTPResponse createErrorResponse(
      Integer statusCode,
      String message
    ) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody(
        '{"error": {"code": ' + statusCode + ', "message": "' + message + '"}'
      );
      res.setStatusCode(statusCode);
      return res;
    }
  }
}
