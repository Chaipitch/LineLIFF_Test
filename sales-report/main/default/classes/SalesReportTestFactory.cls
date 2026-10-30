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

  /** UI API field info as returned in objectInfos.Task.fields. */
  public static Map<String, Object> fieldInfo(
    String dataType,
    String label,
    Boolean required,
    Integer length
  ) {
    return new Map<String, Object>{
      'dataType' => dataType,
      'label' => label,
      'required' => required,
      'createable' => true,
      'length' => length
    };
  }

  /** Task field infos like dev5's (2026-10-30), with Description labelled "Comments". */
  public static Map<String, Object> taskFieldInfos() {
    return new Map<String, Object>{
      'Subject' => fieldInfo('ComboBox', 'Subject', false, 255),
      'Type' => fieldInfo('Picklist', 'Type', false, 255),
      'ActivityDate' => fieldInfo('Date', 'Due Date Only', false, 0),
      'Description' => fieldInfo('TextArea', 'Comments', false, 32000),
      'Status' => fieldInfo('Picklist', 'Status', true, 255),
      'Priority' => fieldInfo('Picklist', 'Priority', true, 20),
      'OwnerId' => fieldInfo('Reference', 'Assigned To', true, 18)
    };
  }

  /** Body of GET ui-api/object-info/Task. */
  public static String taskObjectInfoBody(Map<String, Object> fieldInfos) {
    return JSON.serialize(
      new Map<String, Object>{
        'apiName' => 'Task',
        'label' => 'Task',
        'defaultRecordTypeId' => '012000000000000AAA',
        'fields' => fieldInfos
      }
    );
  }

  public static String taskObjectInfoBody() {
    return taskObjectInfoBody(taskFieldInfos());
  }

  /** Body of GET ui-api/layout/Task?mode=Create: one section, required items = layoutRequired. */
  public static String taskLayoutBody(Set<String> layoutRequired) {
    List<Object> items = new List<Object>();
    for (String name : taskFieldInfos().keySet()) {
      items.add(
        new Map<String, Object>{
          'required' => layoutRequired.contains(name),
          'layoutComponents' => new List<Object>{
            new Map<String, Object>{ 'apiName' => name }
          }
        }
      );
    }
    for (String name : layoutRequired) {
      if (!taskFieldInfos().containsKey(name)) {
        items.add(
          new Map<String, Object>{
            'required' => true,
            'layoutComponents' => new List<Object>{
              new Map<String, Object>{ 'apiName' => name }
            }
          }
        );
      }
    }
    return JSON.serialize(
      new Map<String, Object>{
        'sections' => new List<Object>{
          new Map<String, Object>{
            'layoutRows' => new List<Object>{
              new Map<String, Object>{ 'layoutItems' => items }
            }
          }
        }
      }
    );
  }

  /** dev5's Task layout (2026-10-30) requires Subject, Assigned To, Priority and Status. */
  public static String taskLayoutBody() {
    return taskLayoutBody(
      new Set<String>{ 'Subject', 'OwnerId', 'Priority', 'Status' }
    );
  }

  /** Body of GET ui-api/object-info/Task/picklist-values/<record type>: Type = Visit / Call, defaults Open / Normal. */
  public static String taskPicklistsBody() {
    return '{"picklistFieldValues":{' +
      '"Type":{"defaultValue":null,"values":[' +
      '{"value":"Visit","label":"Customer Visit"},' +
      '{"value":"Call","label":"Phone Call"}]},' +
      '"Status":{"defaultValue":{"value":"Open","label":"Open"},"values":[{"value":"Open","label":"Open"}]},' +
      '"Priority":{"defaultValue":{"value":"Normal","label":"Normal"},"values":[{"value":"Normal","label":"Normal"}]}}}';
  }

  /** Mock answering the rep-session Task calls: object info, layout, picklists, the Account query and the create. */
  public static SalesReportHttpMock taskApiMock(
    String objectInfoBody,
    String layoutBody
  ) {
    return new SalesReportHttpMock(500, '{}')
      .route('api.line.me', 200, verifyBody())
      .route('/ui-api/object-info/Task', 200, objectInfoBody)
      .route('/ui-api/layout/Task', 200, layoutBody)
      .route(
        '/ui-api/object-info/Task/picklist-values/',
        200,
        taskPicklistsBody()
      )
      .route(
        '/query?q=',
        200,
        '{"totalSize":1,"done":true,"records":[{"Id":"001000000000001AAA","Name":"Toyota Motor Thailand"}]}'
      )
      .route(
        '/sobjects/Task',
        201,
        '{"id":"00T000000000001AAA","success":true,"errors":[]}'
      );
  }

  public static SalesReportHttpMock taskApiMock() {
    return taskApiMock(taskObjectInfoBody(), taskLayoutBody());
  }
}
