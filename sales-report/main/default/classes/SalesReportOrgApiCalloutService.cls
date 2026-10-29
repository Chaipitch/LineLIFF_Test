/**
 * Calls to this org's own REST API with a session of the linked rep (Option B), so sharing, FLS, validation rules
 * and "Created By" are the rep's. The access token is held in memory for the request only and never logged.
 */
public with sharing class SalesReportOrgApiCalloutService {
  public static final String API_VERSION = 'v68.0';
  public static final String USER_INFO_PATH = '/services/oauth2/userinfo';
  private static final Integer TIMEOUT_MS = 20000;

  private final String accessToken;

  public SalesReportOrgApiCalloutService(String accessToken) {
    this.accessToken = accessToken;
  }

  /** OpenID Connect userinfo of the session's user (name, preferred_username, user_id, …). */
  public Map<String, Object> userInfo() {
    return (Map<String, Object>) getJson(USER_INFO_PATH);
  }

  /** GET a path on the org's own domain and parse the JSON response. */
  public Object getJson(String path) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + path);
    req.setMethod('GET');
    req.setTimeout(TIMEOUT_MS);
    req.setHeader('Authorization', 'Bearer ' + accessToken);
    req.setHeader('Accept', 'application/json');

    HttpResponse res;
    try {
      res = new Http().send(req);
    } catch (CalloutException e) {
      throw SalesReportException.of(
        SalesReportException.SESSION_ERROR,
        502,
        'Could not reach the Salesforce API: ' + e.getMessage()
      );
    }
    Integer status = res.getStatusCode();
    if (status == 401) {
      throw SalesReportException.of(
        SalesReportException.SESSION_ERROR,
        502,
        'The Salesforce API rejected the session of the linked user.'
      );
    }
    if (status < 200 || status > 299) {
      throw SalesReportException.of(
        SalesReportException.SESSION_ERROR,
        502,
        'The Salesforce API answered HTTP ' + status + ' for ' + path
      );
    }
    try {
      return JSON.deserializeUntyped(res.getBody());
    } catch (JSONException e) {
      throw SalesReportException.of(
        SalesReportException.SESSION_ERROR,
        502,
        'The Salesforce API answered with unreadable JSON for ' + path
      );
    }
  }
}
