/**
 * Test data for Sales Report tests. Fake values only.
 */
@IsTest
public with sharing class SalesReportTestFactory {
  public static final String CHANNEL_ID = '1234567890';
  public static final String LIFF_ID = '1234567890-AbCdEfGh';
  public static final String LINE_USER_ID = 'U0123456789abcdef0123456789abcdef';
  public static final String DISPLAY_NAME = 'Test Rep';
  public static final String ID_TOKEN = 'header.payload.signature';

  public static SalesReport_Settings__c settings(
    Boolean enabled,
    String logLevel
  ) {
    SalesReport_Settings__c s = new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Line_Login_Channel_Id__c = CHANNEL_ID,
      Liff_Id__c = LIFF_ID,
      Enabled__c = enabled,
      Log_Level__c = logLevel
    );
    insert s;
    return s;
  }

  public static SalesReport_Settings__c settings() {
    return settings(true, 'DEBUG');
  }

  /** Verify-endpoint success body; expiry in seconds from now (negative = already expired). */
  public static String verifyBody(
    String aud,
    String iss,
    Integer expiresInSeconds
  ) {
    Long now = Datetime.now().getTime() / 1000;
    return JSON.serialize(
      new Map<String, Object>{
        'iss' => iss,
        'sub' => LINE_USER_ID,
        'aud' => aud,
        'exp' => now + expiresInSeconds,
        'iat' => now - 60,
        'name' => DISPLAY_NAME,
        'picture' => 'https://profile.line-scdn.net/test'
      }
    );
  }

  public static String verifyBody() {
    return verifyBody(CHANNEL_ID, 'https://access.line.me', 3600);
  }

  public static String lineError(String description) {
    return JSON.serialize(
      new Map<String, Object>{
        'error' => 'invalid_request',
        'error_description' => description
      }
    );
  }

  public static RestRequest meRequest(String headerName, String token) {
    RestRequest req = new RestRequest();
    req.httpMethod = 'GET';
    req.requestURI = '/salesreport/v1/me';
    if (headerName != null) {
      req.headers.put(headerName, token);
    }
    RestContext.request = req;
    RestContext.response = new RestResponse();
    return req;
  }
}
