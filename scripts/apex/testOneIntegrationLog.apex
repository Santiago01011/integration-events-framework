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
    'testing-Productos',
    'WARNING',
    'CORR-TEST-008',
    null,
    '{""errorStackTrace"":""Class.SAPB1ApiService.authenticate: line 76, column 1\nClass.SAPB1ApiService.getWithAuthentication: line 157, column 1\nClass.SAPB1ApiService.fetchOnePage: line 218, column 1\nClass.SAPB1ApiService.fetchOnePageWithLazyAuth: line 317, column 1\nClass.BasePaginatedBatchJob.executeIteration: line 440, column 1\nClass.BasePaginatedBatchJob.execute: line 422, column 1"",""rootCauseError"":""Exception in execute: SAP B1 Authentication failed: <!DOCTYPE html>\n<html lang=\""en\"">\n<head>\n<meta charset=\""utf-8\"">\n<title>Error</title>\n</head>\n<body>\n<pre>Cannot POST /api/Login</pre>\n</body>\n</html>\n"",""source"":""SAP B1"",""chainErrors"":[""SAP B1 Authentication failed: <!DOCTYPE html>\n<html lang=\""en\"">\n<head>\n<meta charset=\""utf-8\"">\n<title>Error</title>\n</head>\n<body>\n<pre>Cannot POST /api/Login</pre>\n</body>\n</html>\n""],""totalApiCallouts"":10,""contactsSkipped"":458,""contactsUpserted"":51,""contactsProcessed"":509,""totalRecords"":0,""totalPages"":0,""authSuccess"":false,""mode"":""LIVE"",""database"":""CMK"",""integration"":""Contacts Integration""}'
);