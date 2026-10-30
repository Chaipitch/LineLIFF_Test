@IsTest
private class SalesReportActivityControllerTest {
  private static Map<String, Object> responseJson() {
    return (Map<String, Object>) JSON.deserializeUntyped(
      RestContext.response.responseBody.toString()
    );
  }

  private static void linkedRep() {
    SalesReport_Settings__c settings = SalesReportTestFactory.settings();
    settings.Eca_Consumer_Key__c = 'test-consumer-key';
    update settings;
    SalesReportTestFactory.link(
      SalesReportTestFactory.LINE_USER_ID,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );
    SalesReportSessionCalloutService.testAccessToken = 'session-token';
  }

  private static RestRequest request(String method, String body) {
    RestRequest req = SalesReportTestFactory.meRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );
    req.httpMethod = method;
    req.requestURI = '/salesreport/v1/activity';
    if (body != null) {
      req.requestBody = Blob.valueOf(body);
    }
    return req;
  }

  @IsTest
  static void linkedRepGetsTheForm() {
    linkedRep();
    Test.setMock(HttpCalloutMock.class, SalesReportTestFactory.taskApiMock());
    request('GET', null);

    Test.startTest();
    SalesReportActivityController.form();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    List<Object> fields = (List<Object>) responseJson().get('fields');
    Assert.areEqual(3, fields.size(), 'Field set members');
  }

  @IsTest
  static void linkedRepCreatesTheTask() {
    linkedRep();
    Test.setMock(HttpCalloutMock.class, SalesReportTestFactory.taskApiMock());
    request(
      'POST',
      '{"accountId":"001000000000001AAA","values":{"Type":"Call","Description":"Follow-up call"}}'
    );

    Test.startTest();
    SalesReportActivityController.create();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    Map<String, Object> result = responseJson();
    Assert.areEqual('00T000000000001AAA', result.get('id'), 'Task ID');
    Assert.areEqual(
      'Phone Call – Toyota Motor Thailand',
      result.get('subject'),
      'Subject'
    );
  }

  @IsTest
  static void invalidInputAnswers400WithFields() {
    linkedRep();
    Test.setMock(HttpCalloutMock.class, SalesReportTestFactory.taskApiMock());
    request('POST', '{"values":{}}');

    Test.startTest();
    SalesReportActivityController.create();
    Test.stopTest();

    Assert.areEqual(400, RestContext.response.statusCode, 'Bad request');
    Map<String, Object> error = (Map<String, Object>) responseJson()
      .get('error');
    Assert.areEqual(
      SalesReportException.INVALID_INPUT,
      error.get('code'),
      'Code'
    );
    Assert.isTrue(
      ((Map<String, Object>) error.get('fields')).containsKey('accountId'),
      'Account highlighted'
    );
  }

  @IsTest
  static void notLinkedAnswers403() {
    SalesReportTestFactory.settings(true, 'WARN');
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    request('GET', null);

    Test.startTest();
    SalesReportActivityController.form();
    Test.stopTest();

    Assert.areEqual(403, RestContext.response.statusCode, 'Forbidden');
  }

  @IsTest
  static void notLinkedCannotCreate() {
    SalesReportTestFactory.settings(true, 'WARN');
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    request('POST', '{}');

    Test.startTest();
    SalesReportActivityController.create();
    Test.stopTest();

    Assert.areEqual(403, RestContext.response.statusCode, 'Forbidden');
  }
}
