/**
 * Calls to this org's own REST API with a session of the linked rep (Option B), so sharing, FLS, validation rules
 * and "Created By" are the rep's. The access token is held in memory for the request only and never logged.
 *
 * Not a Named Credential (PMD ApexSuggestUsingNamedCred): the token is minted per request for whichever rep is
 * calling (JWT bearer, D-02/D-16), while the running user is the Site guest; a Named Credential can't hold that.
 */
@SuppressWarnings('PMD.ApexSuggestUsingNamedCred')
public with sharing class SalesReportOrgApiCalloutService {
  public static final String API_VERSION = 'v68.0';
  public static final String USER_INFO_PATH = '/services/oauth2/userinfo';
  private static final Integer TIMEOUT_MS = 20000;

  private final String accessToken;
  /** The rep's time zone (from their User record), so "today" means the rep's today. */
  public final String timeZoneSidKey;

  public SalesReportOrgApiCalloutService(String accessToken) {
    this(accessToken, null);
  }

  public SalesReportOrgApiCalloutService(
    String accessToken,
    String timeZoneSidKey
  ) {
    this.accessToken = accessToken;
    this.timeZoneSidKey = timeZoneSidKey;
  }

  /** Today's date in the rep's time zone (the running user's when unknown). */
  public Date repToday() {
    if (String.isBlank(timeZoneSidKey)) {
      return Date.today();
    }
    return Date.valueOf(Datetime.now().format('yyyy-MM-dd', timeZoneSidKey));
  }

  /** OpenID Connect userinfo of the session's user (name, preferred_username, user_id, …). */
  public Map<String, Object> userInfo() {
    return (Map<String, Object>) getJson(USER_INFO_PATH);
  }

  /** SOQL as the rep (sharing, FLS and object access are the rep's). Returns the records of the first page. */
  public List<Object> query(String soql) {
    Map<String, Object> result = (Map<String, Object>) getJson(
      '/services/data/' +
        API_VERSION +
        '/query?q=' +
        EncodingUtil.urlEncode(soql, 'UTF-8')
    );
    List<Object> records = (List<Object>) result.get('records');
    return records == null ? new List<Object>() : records;
  }

  /** User Interface API resource as the rep, e.g. 'record-defaults/create/Task' (layouts, defaults, labels). */
  public Map<String, Object> uiApi(String resource) {
    return (Map<String, Object>) getJson(
      '/services/data/' + API_VERSION + '/ui-api/' + resource
    );
  }

  /**
   * Creates one record as the rep (POST sobjects/<type>) and returns its ID. Salesforce's own save errors
   * (validation rules, required fields, field access) come back as SAVE_FAILED with the fields they name.
   */
  public String create(String sObjectType, Map<String, Object> fields) {
    Map<String, Object> result = (Map<String, Object>) send(
      'POST',
      '/services/data/' + API_VERSION + '/sobjects/' + sObjectType,
      JSON.serialize(fields)
    );
    return (String) result.get('id');
  }

  /** GET a path on the org's own domain and parse the JSON response. */
  public Object getJson(String path) {
    return send('GET', path, null);
  }

  private Object send(String method, String path, String body) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + path);
    req.setMethod(method);
    req.setTimeout(TIMEOUT_MS);
    req.setHeader('Authorization', 'Bearer ' + accessToken);
    req.setHeader('Accept', 'application/json');
    if (body != null) {
      req.setHeader('Content-Type', 'application/json');
      req.setBody(body);
    }

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
    if (method == 'POST' && (status == 400 || status == 403 || status == 404)) {
      SalesReportException rejected = saveErrors(res.getBody());
      if (rejected != null) {
        throw rejected;
      }
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

  /**
   * Salesforce's error list [{ message, errorCode, fields }] → SAVE_FAILED. Messages are already in the rep's
   * language (their session). Errors naming fields are shown next to those fields; the rest above the form.
   * Returns null when the body isn't an error list.
   */
  @TestVisible
  static SalesReportException saveErrors(String body) {
    Object parsed;
    try {
      parsed = JSON.deserializeUntyped(body);
    } catch (JSONException e) {
      return null;
    }
    if (!(parsed instanceof List<Object>)) {
      return null;
    }
    List<String> messages = new List<String>();
    Map<String, String> fieldErrors = new Map<String, String>();
    for (Object item : (List<Object>) parsed) {
      if (!(item instanceof Map<String, Object>)) {
        return null;
      }
      Map<String, Object> error = (Map<String, Object>) item;
      String message = String.valueOf(error.get('message'));
      List<Object> fields = (List<Object>) error.get('fields');
      if (fields == null || fields.isEmpty()) {
        if (!messages.contains(message)) {
          messages.add(message);
        }
        continue;
      }
      for (Object field : fields) {
        fieldErrors.put(String.valueOf(field), message);
      }
    }
    if (messages.isEmpty() && fieldErrors.isEmpty()) {
      return null;
    }
    return SalesReportException.withFields(
      SalesReportException.SAVE_FAILED,
      400,
      messages.isEmpty()
        ? 'Salesforce could not save this record.'
        : String.join(messages, ' '),
      fieldErrors
    );
  }
}
