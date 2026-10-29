@IsTest
private class SalesReportAccountControllerTest {
  private static Map<String, Object> responseJson() {
    return (Map<String, Object>) JSON.deserializeUntyped(
      RestContext.response.responseBody.toString()
    );
  }

  private static void request(String term) {
    SalesReportTestFactory.meRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );
    RestContext.request.requestURI = '/salesreport/v1/accounts';
    RestContext.request.params.put('q', term);
  }

  @IsTest
  static void linkedRepGetsAccountsThroughOwnSession() {
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
        '/query?q=',
        200,
        '{"totalSize":1,"done":true,"records":[{"Id":"001000000000001AAA","Name":"Toyota Motor Thailand"}]}'
      );
    Test.setMock(HttpCalloutMock.class, mock);
    request('toy');

    Test.startTest();
    SalesReportAccountController.search();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    List<Object> accounts = (List<Object>) responseJson().get('accounts');
    Assert.areEqual(1, accounts.size(), 'One account');
    Assert.areEqual(
      '001000000000001AAA',
      ((Map<String, Object>) accounts[0]).get('id'),
      'Account ID'
    );
    Assert.areEqual(
      'Bearer session-token',
      mock.lastRequest.getHeader('Authorization'),
      'Queried as the rep'
    );
  }

  @IsTest
  static void notLinkedAnswers403() {
    SalesReportTestFactory.settings(true, 'WARN');
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    request('toy');

    Test.startTest();
    SalesReportAccountController.search();
    Test.stopTest();

    Assert.areEqual(403, RestContext.response.statusCode, 'Forbidden');
    Map<String, Object> error = (Map<String, Object>) responseJson()
      .get('error');
    Assert.areEqual(
      SalesReportException.NOT_LINKED,
      error.get('code'),
      'Page shows Connect again'
    );
  }

  @IsTest
  static void missingTokenAnswers401() {
    SalesReportTestFactory.settings(true, 'WARN');
    SalesReportTestFactory.meRequest(null, null);

    SalesReportAccountController.search();

    Assert.areEqual(401, RestContext.response.statusCode, 'Unauthorised');
  }
}
