@IsTest
private class SalesReportConnectionControllerTest {
  private static Map<String, Object> responseJson() {
    return (Map<String, Object>) JSON.deserializeUntyped(
      RestContext.response.responseBody.toString()
    );
  }

  private static Map<String, Object> errorJson() {
    return (Map<String, Object>) responseJson().get('error');
  }

  @IsTest
  static void returnsDisplayNameAndNotLinked() {
    SalesReportTestFactory.settings();
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    SalesReportTestFactory.restRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );

    Test.startTest();
    SalesReportConnectionController.getConnection();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    Assert.areEqual(
      'no-store',
      RestContext.response.headers.get('Cache-Control'),
      'Never cached'
    );
    Map<String, Object> body = responseJson();
    Assert.areEqual(
      SalesReportTestFactory.DISPLAY_NAME,
      body.get('lineDisplayName'),
      'Display name'
    );
    Assert.areEqual(false, body.get('linked'), 'Linking arrives in L3');
    Assert.isFalse(
      body.containsKey('salesforceUserName'),
      'Nulls are not serialised'
    );
  }

  @IsTest
  static void missingTokenAnswers401AndLogsWarning() {
    SalesReportTestFactory.settings(true, 'WARN');
    SalesReportTestFactory.restRequest(null, null);

    Test.startTest();
    SalesReportConnectionController.getConnection();
    Test.stopTest();

    Assert.areEqual(401, RestContext.response.statusCode, 'Unauthorised');
    Assert.areEqual(
      SalesReportException.TOKEN_MISSING,
      errorJson().get('code'),
      'Error code'
    );
    SalesReport_Log__c log = [
      SELECT Level__c, Source__c, Message__c
      FROM SalesReport_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual('WARN', log.Level__c, 'Logged as warning');
    Assert.areEqual(
      SalesReportConnectionController.SOURCE,
      log.Source__c,
      'Source'
    );
  }

  @IsTest
  static void expiredTokenAnswers401AndLogsOnlyAtInfo() {
    SalesReportTestFactory.settings(true, 'WARN');
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(
        400,
        SalesReportTestFactory.lineError(
          SalesReportLineCalloutService.EXPIRED_DESCRIPTION
        )
      )
    );
    SalesReportTestFactory.restRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );

    Test.startTest();
    SalesReportConnectionController.getConnection();
    Test.stopTest();

    Assert.areEqual(401, RestContext.response.statusCode, 'Unauthorised');
    Assert.areEqual(
      SalesReportException.TOKEN_EXPIRED,
      errorJson().get('code'),
      'Page reloads on this code'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM SalesReport_Log__c WITH SYSTEM_MODE],
      'Routine expiry is not a warning'
    );
  }

  @IsTest
  static void switchedOffAnswers503() {
    SalesReportTestFactory.settings(false, 'WARN');
    SalesReportTestFactory.restRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );

    SalesReportConnectionController.getConnection();

    Assert.areEqual(503, RestContext.response.statusCode, 'Unavailable');
    Assert.areEqual(
      SalesReportException.UNAVAILABLE,
      errorJson().get('code'),
      'Error code'
    );
  }

  @IsTest
  static void unexpectedFailureAnswersGeneric500AndLogsError() {
    SalesReportTestFactory.settings(true, 'WARN');
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    SalesReportTestFactory.restRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );

    SalesReportRestService.fail(
      SalesReportConnectionController.SOURCE,
      new NullPointerException()
    );

    Assert.areEqual(500, RestContext.response.statusCode, 'Internal error');
    Assert.areEqual('INTERNAL', errorJson().get('code'), 'Generic code');
    Assert.areEqual(
      'Something went wrong.',
      errorJson().get('message'),
      'No internals leaked'
    );
    SalesReportLogService.flush();
    SalesReport_Log__c log = [
      SELECT Level__c, Request_Id__c
      FROM SalesReport_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      log.Request_Id__c,
      errorJson().get('reference'),
      'Support reference matches the log entry'
    );
    Assert.areEqual('ERROR', log.Level__c, 'Logged as error');
  }

  @IsTest
  static void linkedRepGetsSalesforceNameThroughOwnSession() {
    SalesReport_Settings__c settings = SalesReportTestFactory.settings();
    settings.Eca_Consumer_Key__c = 'test-consumer-key';
    update settings;
    SalesReportTestFactory.link(
      SalesReportTestFactory.LINE_USER_ID,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );
    SalesReportSessionCalloutService.testAccessToken = 'session-token';
    SalesReportHttpMock mock = new SalesReportHttpMock(500, '{}')
      .route('api.line.me', 200, SalesReportTestFactory.verifyBody())
      .route(
        SalesReportOrgApiCalloutService.USER_INFO_PATH,
        200,
        '{"name":"Rep From Session"}'
      );
    Test.setMock(HttpCalloutMock.class, mock);
    SalesReportTestFactory.restRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );

    Test.startTest();
    SalesReportConnectionController.getConnection();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    Map<String, Object> body = responseJson();
    Assert.areEqual(true, body.get('linked'), 'Linked');
    Assert.areEqual(
      'Rep From Session',
      body.get('salesforceUserName'),
      'Name read as the rep'
    );
    Assert.areEqual(
      'Bearer session-token',
      mock.lastRequest.getHeader('Authorization'),
      'Org API called with the rep session'
    );
  }

  @IsTest
  static void linkedRepWithoutConsumerKeyAnswers503() {
    SalesReportTestFactory.settings(true, 'WARN');
    SalesReportTestFactory.link(
      SalesReportTestFactory.LINE_USER_ID,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    SalesReportTestFactory.restRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );

    Test.startTest();
    SalesReportConnectionController.getConnection();
    Test.stopTest();

    Assert.areEqual(503, RestContext.response.statusCode, 'Not configured');
    Assert.areEqual(
      SalesReportException.CONFIG_MISSING,
      errorJson().get('code'),
      'Error code'
    );
  }
}
