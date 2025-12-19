/**
 * Lightweight client for SAP B1 Service Layer (OData) callouts.
 *
 * Responsibilities
 * - Authenticate against the Service Layer and manage the B1SESSION cookie.
 * - Perform authenticated GET/POST requests with cookie propagation.
 * - Provide a simple pagination helper (fetchAllPaginated) using $skip.
 *
 * Notes
 * - Authentication is done lazily (on first request) if no session cookie is present.
 * - Throws CalloutException on non-200 responses to surface transport errors to callers.
 * - Pagination currently caps at 5 pages for safety; adjust as needed.
 */
public class SAPB1ApiService extends RestClient {
  private String sessionCookie;
  private String database;
  private String username;
  private String password;

  /**
   * Constructs a new SAPB1ApiService bound to a baseURL and credentials.
   * @param baseURL The Service Layer base URL or named credential URL.
   * @param database The CompanyDB to authenticate against.
   * @param username SAP B1 username.
   * @param password SAP B1 password.
   */
  public SAPB1ApiService(
    String baseURL,
    String database,
    String username,
    String password
  ) {
    super(baseURL);
    this.database = database;
    this.username = username;
    this.password = password;
  }

  /**
   * Performs a login against /Login and stores the B1SESSION cookie.
   * Throws CalloutException if login fails.
   */
  public void authenticate() {
    String loginBody = JSON.serialize(
      new Map<String, String>{
        'CompanyDB' => this.database,
        'UserName' => this.username,
        'Password' => this.password,
        'Language' => '25'
      }
    );

    HttpResponse response = this.post('/Login', loginBody);

    if (response.getStatusCode() == 200) {
      this.sessionCookie = extractSessionCookie(response);
    } else {
      throw new CalloutException(
        'SAP B1 Authentication failed: ' + response.getBody()
      );
    }
  }

  /**
   * Returns the current B1SESSION cookie (may be null before authenticate()).
   */
  public String getSessionCookie() {
    return this.sessionCookie;
  }

  /**
   * Extracts the B1SESSION cookie value from a Set-Cookie response header.
   * @param response HttpResponse from Service Layer.
   * @return The cookie string starting with B1SESSION=... or null.
   */
  private String extractSessionCookie(HttpResponse response) {
    String cookieHeader = response.getHeader('Set-Cookie');
    if (String.isNotBlank(cookieHeader)) {
      List<String> cookies = cookieHeader.split(';');
      for (String cookie : cookies) {
        if (cookie.trim().startsWith('B1SESSION=')) {
          return cookie.trim();
        }
      }
    }
    return null;
  }

  /**
   * Performs an authenticated GET, lazily authenticating if required.
   * @param path Relative resource path (e.g., /$crossjoin(...)).
   * @return HttpResponse from Service Layer.
   */
  public HttpResponse getWithAuthentication(String path) {
    if (String.isBlank(this.sessionCookie)) {
      this.authenticate();
    }

    Map<String, String> headers = new Map<String, String>{
      'Cookie' => this.sessionCookie
    };

    return this.makeApiCall(HttpVerb.XGET, path, '', headers);
  }

  /**
   * Performs an authenticated POST, lazily authenticating if required.
   * @param path Relative resource path.
   * @param body JSON body to post.
   * @return HttpResponse from Service Layer.
   */
  public HttpResponse postWithAuthentication(String path, String body) {
    if (String.isBlank(this.sessionCookie)) {
      this.authenticate();
    }

    Map<String, String> headers = new Map<String, String>{
      'Cookie' => this.sessionCookie
    };

    return this.makeApiCall(HttpVerb.XPOST, path, body, headers);
  }

  /**
   * @description Wrapper class to hold a single page response with data and nextLink.
   * Used in the State-Chaining Batch pattern to facilitate pagination.
   */
  public class PageResponse {
    public List<Map<String, Object>> data { get; set; }
    public String nextLink { get; set; }
    public Integer statusCode { get; set; }

    public PageResponse() {
      this.data = new List<Map<String, Object>>();
      this.nextLink = null;
      this.statusCode = null;
    }
  }

  /**
   * @description Fetches a single page of data from SAP B1 OData API.
   * Supports both initial resource paths and odata.nextLink URLs.
   * @param resourcePath The initial OData resource path or a full nextLink URL.
   * @return PageResponse containing the data, nextLink, and status code.
   * @throws CalloutException on non-200 responses.
   */
  public PageResponse fetchOnePage(String resourcePath) {
    PageResponse response = new PageResponse();

    HttpResponse httpResponse = this.getWithAuthentication(resourcePath);
    response.statusCode = httpResponse.getStatusCode();

    if (httpResponse.getStatusCode() == 200) {
      Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
        httpResponse.getBody()
      );
      List<Object> items = (List<Object>) result.get('value');

      if (items != null && !items.isEmpty()) {
        for (Object item : items) {
          response.data.add((Map<String, Object>) item);
        }
      }

      response.nextLink = (String) result.get('odata.nextLink');
    } else {
      throw new CalloutException('SAP B1 API error: ' + httpResponse.getBody());
    }

    return response;
  }

  /**
   * @description Static helper to fetch a single page with explicit credentials.
   * Useful for batch jobs that need to pass BatchContext for diagnostics.
   * @param baseURL Base URL for the SAP B1 Service Layer.
   * @param database CompanyDB name.
   * @param username SAP B1 username.
   * @param password SAP B1 password.
   * @param resourcePath The OData resource path or nextLink.
   * @param batchCtx Optional BatchIntegrationHelper.BatchContext for diagnostics.
   * @return PageResponse with data and nextLink.
   */
  public static PageResponse fetchOnePage(
    String baseURL,
    String database,
    String username,
    String password,
    String resourcePath,
    BatchIntegrationHelper.BatchContext batchCtx
  ) {
    PageResponse pageResponse = new PageResponse();

    try {
      SAPB1ApiService sapService = new SAPB1ApiService(
        baseURL,
        database,
        username,
        password
      );
      pageResponse = sapService.fetchOnePage(resourcePath);

      if (batchCtx != null) {
        batchCtx.authSuccess = true;
        batchCtx.totalPagesProcessed++;
        batchCtx.lastResponseStatus = pageResponse.statusCode;
      }
    } catch (Exception ex) {
      if (batchCtx != null) {
        batchCtx.authSuccess = false;
        batchCtx.rootCauseError = 'Error fetching page: ' + ex.getMessage();
        batchCtx.errorStackTrace = ex.getStackTraceString();
      }
    }

    return pageResponse;
  }
}
