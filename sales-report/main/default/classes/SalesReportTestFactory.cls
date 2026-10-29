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

  public static SalesReportLineVerifyData identity(String lineUserId) {
    SalesReportLineVerifyData data = new SalesReportLineVerifyData();
    data.sub = lineUserId;
    data.name = DISPLAY_NAME;
    data.aud = CHANNEL_ID;
    data.iss = 'https://access.line.me';
    return data;
  }

  /** A rep with the running user's profile (no profile names, P2), optionally with the Sales Report User set. */
  public static User rep(String tag, Boolean withSalesReportAccess) {
    String unique =
      tag + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    User u = new User(
      ProfileId = UserInfo.getProfileId(),
      LastName = 'Rep ' + tag,
      Alias = ('sr' + tag).left(8),
      Email = unique + '@example.invalid',
      Username = unique + '@salesreport.example.invalid',
      TimeZoneSidKey = 'Asia/Bangkok',
      LocaleSidKey = 'en_US',
      LanguageLocaleKey = 'en_US',
      EmailEncodingKey = 'UTF-8'
    );
    // Setup objects in their own context, so tests can insert other records afterwards (no mixed DML).
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert u;
      if (withSalesReportAccess) {
        insert new PermissionSetAssignment(
          AssigneeId = u.Id,
          PermissionSetId = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'SalesReport_User'
            LIMIT 1
          ]
          .Id
        );
      }
    }
    return [SELECT Id, Name, Username, IsActive FROM User WHERE Id = :u.Id];
  }

  public static SalesReport_Line_Link__c link(
    String lineUserId,
    Id userId,
    String status
  ) {
    SalesReport_Line_Link__c link = new SalesReport_Line_Link__c(
      Line_User_Id__c = lineUserId,
      User__c = userId,
      Status__c = status,
      Active_User_Key__c = status == SalesReportLinkService.STATUS_ACTIVE
        ? String.valueOf(userId)
        : null,
      Linked_At__c = Datetime.now().addDays(-1)
    );
    Database.insert(link, AccessLevel.SYSTEM_MODE);
    return link;
  }
}
