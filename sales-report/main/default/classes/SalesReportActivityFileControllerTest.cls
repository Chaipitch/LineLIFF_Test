@IsTest
private class SalesReportActivityFileControllerTest {
  private static void request(Map<String, String> params, Blob body) {
    RestRequest req = SalesReportTestFactory.meRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );
    req.httpMethod = 'POST';
    req.requestURI = '/salesreport/v1/activity/files';
    req.params.putAll(params);
    req.requestBody = body;
  }

  private static Map<String, Object> responseJson() {
    return (Map<String, Object>) JSON.deserializeUntyped(
      RestContext.response.responseBody.toString()
    );
  }

  @IsTest
  static void linkedRepAttachesAFile() {
    SalesReport_Settings__c settings = SalesReportTestFactory.settings();
    settings.Eca_Consumer_Key__c = 'test-consumer-key';
    update settings;
    SalesReportTestFactory.link(
      SalesReportTestFactory.LINE_USER_ID,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );
    SalesReportSessionCalloutService.testAccessToken = 'session-token';
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.taskFileMock(
        UserInfo.getUserId(),
        Datetime.now(),
        0
      )
    );
    request(
      new Map<String, String>{
        'taskId' => '00T000000000001EAA',
        'name' => 'visit.pdf'
      },
      Blob.valueOf('%PDF-1.7')
    );

    Test.startTest();
    SalesReportActivityFileController.attach();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    Assert.areEqual('visit.pdf', responseJson().get('name'), 'File name');
  }

  @IsTest
  static void notLinkedAnswers403() {
    SalesReportTestFactory.settings(true, 'WARN');
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    request(new Map<String, String>(), Blob.valueOf('x'));

    Test.startTest();
    SalesReportActivityFileController.attach();
    Test.stopTest();

    Assert.areEqual(403, RestContext.response.statusCode, 'Forbidden');
  }
}
