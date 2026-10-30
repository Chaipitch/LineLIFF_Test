@IsTest
private class SalesReportOrgApiCalloutServiceTest {
  private static SalesReportException getExpectingFailure() {
    try {
      new SalesReportOrgApiCalloutService('token').userInfo();
    } catch (SalesReportException e) {
      return e;
    }
    Assert.fail('Expected a SalesReportException');
    return null;
  }

  @IsTest
  static void userInfoUsesBearerTokenOnOwnDomain() {
    SalesReportHttpMock mock = new SalesReportHttpMock(
      200,
      '{"name":"Test Rep","user_id":"005000000000001"}'
    );
    Test.setMock(HttpCalloutMock.class, mock);

    Map<String, Object> info = new SalesReportOrgApiCalloutService(
        'session-token'
      )
      .userInfo();

    Assert.areEqual('Test Rep', info.get('name'), 'Name');
    Assert.areEqual(
      URL.getOrgDomainUrl().toExternalForm() +
      SalesReportOrgApiCalloutService.USER_INFO_PATH,
      mock.lastRequest.getEndpoint(),
      'Endpoint'
    );
    Assert.areEqual(
      'Bearer session-token',
      mock.lastRequest.getHeader('Authorization'),
      'Bearer token'
    );
  }

  @IsTest
  static void rejectedSessionIsSessionError() {
    Test.setMock(HttpCalloutMock.class, new SalesReportHttpMock(401, '[]'));
    Assert.areEqual(
      SalesReportException.SESSION_ERROR,
      getExpectingFailure().code,
      '401'
    );
  }

  @IsTest
  static void otherHttpErrorIsSessionError() {
    Test.setMock(HttpCalloutMock.class, new SalesReportHttpMock(500, '[]'));
    Assert.areEqual(
      SalesReportException.SESSION_ERROR,
      getExpectingFailure().code,
      '500'
    );
  }

  @IsTest
  static void unreadableJsonIsSessionError() {
    Test.setMock(HttpCalloutMock.class, new SalesReportHttpMock(200, '<html>'));
    Assert.areEqual(
      SalesReportException.SESSION_ERROR,
      getExpectingFailure().code,
      'Bad JSON'
    );
  }

  @IsTest
  static void unreachableIsSessionError() {
    Test.setMock(HttpCalloutMock.class, SalesReportHttpMock.unreachable());
    Assert.areEqual(
      SalesReportException.SESSION_ERROR,
      getExpectingFailure().code,
      'Unreachable'
    );
  }

  @IsTest
  static void createPostsJsonAsTheRep() {
    SalesReportHttpMock mock = new SalesReportHttpMock(
      201,
      '{"id":"00T000000000001AAA","success":true,"errors":[]}'
    );
    Test.setMock(HttpCalloutMock.class, mock);

    String id = new SalesReportOrgApiCalloutService('session-token')
      .create('Task', new Map<String, Object>{ 'Subject' => 'Visit' });

    Assert.areEqual('00T000000000001AAA', id, 'New ID');
    Assert.areEqual('POST', mock.lastRequest.getMethod(), 'Method');
    Assert.isTrue(
      mock.lastRequest.getEndpoint().endsWith('/sobjects/Task'),
      'Endpoint'
    );
    Assert.areEqual(
      'Visit',
      ((Map<String, Object>) JSON.deserializeUntyped(
          mock.lastRequest.getBody()
        ))
        .get('Subject'),
      'Body'
    );
  }

  @IsTest
  static void saveErrorsSplitFieldAndFormMessages() {
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(
        400,
        '[{"message":"Close the deal in Salesforce.","errorCode":"FIELD_CUSTOM_VALIDATION_EXCEPTION","fields":[]},' +
        '{"message":"Required fields are missing: [Region]","errorCode":"REQUIRED_FIELD_MISSING","fields":["Region__c"]}]'
      )
    );
    try {
      new SalesReportOrgApiCalloutService('token')
        .create('Task', new Map<String, Object>());
      Assert.fail('Expected a save error');
    } catch (SalesReportException e) {
      Assert.areEqual(SalesReportException.SAVE_FAILED, e.code, 'Code');
      Assert.areEqual(400, e.statusCode, 'Status');
      Assert.areEqual(
        'Close the deal in Salesforce.',
        e.getMessage(),
        'Form message'
      );
      Assert.areEqual(
        'Required fields are missing: [Region]',
        e.fieldErrors.get('Region__c'),
        'Field message'
      );
    }
  }

  @IsTest
  static void postErrorWithoutErrorListIsSessionError() {
    Test.setMock(HttpCalloutMock.class, new SalesReportHttpMock(400, '{}'));
    try {
      new SalesReportOrgApiCalloutService('token')
        .create('Task', new Map<String, Object>());
      Assert.fail('Expected an error');
    } catch (SalesReportException e) {
      Assert.areEqual(SalesReportException.SESSION_ERROR, e.code, 'Code');
    }
    Assert.isNull(
      SalesReportOrgApiCalloutService.saveErrors('not json'),
      'Not JSON'
    );
    Assert.isNull(SalesReportOrgApiCalloutService.saveErrors('[]'), 'Empty');
    Assert.isNull(
      SalesReportOrgApiCalloutService.saveErrors('[1]'),
      'Not errors'
    );
  }

  @IsTest
  static void repTodayUsesTheRepTimeZone() {
    Date expected = Date.valueOf(
      Datetime.now().format('yyyy-MM-dd', 'Pacific/Kiritimati')
    );
    Assert.areEqual(
      expected,
      new SalesReportOrgApiCalloutService('token', 'Pacific/Kiritimati')
        .repToday(),
      'Rep time zone'
    );
    Assert.areEqual(
      Date.today(),
      new SalesReportOrgApiCalloutService('token').repToday(),
      'Running user without a zone'
    );
  }

  @IsTest
  static void uiApiReadsAsTheRep() {
    SalesReportHttpMock mock = new SalesReportHttpMock(200, '{"layout":{}}');
    Test.setMock(HttpCalloutMock.class, mock);

    Map<String, Object> result = new SalesReportOrgApiCalloutService('token')
      .uiApi('record-defaults/create/Task');

    Assert.isTrue(result.containsKey('layout'), 'Parsed');
    Assert.isTrue(
      mock.lastRequest.getEndpoint()
        .endsWith('/ui-api/record-defaults/create/Task'),
      'UI API path'
    );
  }
}
