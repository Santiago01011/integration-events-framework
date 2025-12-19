@IsTest
private class RestClientTest {
  private class MockHttpResponseGenerator implements HttpCalloutMock {
    private Integer statusCode;
    private String body;

    public MockHttpResponseGenerator(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setStatusCode(this.statusCode);
      res.setBody(this.body);
      return res;
    }
  }

  @IsTest
  static void testGetMethod() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(200, '{"success":true}')
    );

    Test.startTest();
    RestClient client = new RestClient('TestCredential');
    HttpResponse response = client.get('/test');
    Test.stopTest();

    System.assertEquals(200, response.getStatusCode());
    System.assert(response.getBody().contains('success'));
  }

  @IsTest
  static void testPostMethod() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(201, '{"created":true}')
    );

    Test.startTest();
    RestClient client = new RestClient('TestCredential');
    HttpResponse response = client.post('/test', '{"data":"value"}');
    Test.stopTest();

    System.assertEquals(201, response.getStatusCode());
    System.assert(response.getBody().contains('created'));
  }

  @IsTest
  static void testPutMethod() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(200, '{"updated":true}')
    );

    Test.startTest();
    RestClient client = new RestClient('TestCredential');
    HttpResponse response = client.put('/test', '{"data":"updated"}');
    Test.stopTest();

    System.assertEquals(200, response.getStatusCode());
  }

  @IsTest
  static void testPatchMethod() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(200, '{"patched":true}')
    );

    Test.startTest();
    RestClient client = new RestClient('TestCredential');
    HttpResponse response = client.patch('/test', '{"data":"patched"}');
    Test.stopTest();

    System.assertEquals(200, response.getStatusCode());
  }

  @IsTest
  static void testGetMethodErrorResponse() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(500, '{"error":"Internal Server Error"}')
    );

    Test.startTest();
    RestClient client = new RestClient('TestCredential');
    HttpResponse response = client.get('/test');
    Test.stopTest();

    System.assertEquals(500, response.getStatusCode());
    System.assert(response.getBody().contains('error'));
  }

  @IsTest
  static void testPostMethodErrorResponse() {
    Test.setMock(
      HttpCalloutMock.class,
      new MockHttpResponseGenerator(400, '{"error":"Bad Request"}')
    );

    Test.startTest();
    RestClient client = new RestClient('TestCredential');
    HttpResponse response = client.post('/test', '{}');
    Test.stopTest();

    System.assertEquals(400, response.getStatusCode());
    System.assert(response.getBody().contains('error'));
  }

  private class MockHttpCalloutFailure implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      throw new CalloutException('Mock callout exception');
    }
  }

  @IsTest
  static void testCalloutException() {
    Test.setMock(HttpCalloutMock.class, new MockHttpCalloutFailure());

    Test.startTest();
    RestClient client = new RestClient('TestCredential');

    try {
      client.get('/test');
      System.assert(false, 'Expected CalloutException was not thrown');
    } catch (CalloutException e) {
      System.assert(e.getMessage().contains('Mock callout exception'));
    }

    Test.stopTest();
  }
}
