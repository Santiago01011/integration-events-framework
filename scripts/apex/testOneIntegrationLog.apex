/**
 * 
 *
   * @description Canonical emitter: publishes a neutral observation with correlation.
   * @param integrationCode Integration identifier from metadata.
   * @param observationType Fact-based observation type.
   * @param correlationId Correlation identifier to propagate.
   * @param parentEventId Optional parent event identifier.
   * @param context Opaque context payload (JSON or string).
  public static void emit(
    String integrationCode,
    String observationType,
    String correlationId,
    String parentEventId,
    String context
 */

IntegrationEventPublisher.emit(
  'testing-Direcciones',
  'BATCH_COMPLETE',
  'CORR-TEST-010',
  null,
  '{"BPAddresses":[{"AddressName":"Test Direccion","AddressType":"S","Street":"AV AMERICO VESPUCIO 1260 prueba","City":"Cordillera","County":"CL","State":null,"Country":null,"U_Ruta":null,"U_Telefono":null,"U_Email":null,"U_Aprobado":"N","U_Contacto":null,"U_Latitud":null,"U_Longitud":null,"U_Tipo_Res":null,"U_Hor_Desp":null}],"ContactEmployees":[{"Name":"COBRANZAS","FirstName":null,"LastName":"COBRANZAS","Phone1":"0349215223750","E_Mail":"santiago.zapata@procontacto.com.mx"},{"Name":"SANTIAGO ZAPATA","FirstName":"SANTIAGO","LastName":"ZAPATA","Phone1":"0349215223750","E_Mail":"santiago.zapata@procontacto.com.mx"}],"CardCode":"PN889083808","CardName":"Test_Cliente_Post","CardType":"cLid","GroupCode":100,"FederalTaxID":"99999999-9","Cellular":"0349215223750","EmailAddress":"santiago.zapata@procontacto.com.mx","U_SEI_GNRP":"FARMACIAS INDEPENDIENTES","PayTermsGrpCode":null,"U_Estratificacion":null,"Valid":"tYES","Frozen":"tNO","SalesPersonCode":23,"U_Grupo":null,"U_Verificacion":"00","Notes":null,"U_Cobrador":null}'
);
