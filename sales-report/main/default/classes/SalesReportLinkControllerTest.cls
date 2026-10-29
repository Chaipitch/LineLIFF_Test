@IsTest
private class SalesReportLinkControllerTest {
  private static Map<String, Object> responseJson() {
    return (Map<String, Object>) JSON.deserializeUntyped(
      RestContext.response.responseBody.toString()
    );
  }

  @IsTest
  static void startReturnsOneTimeLinkUrl() {
    SalesReportTestFactory.settings();
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    SalesReportTestFactory.meRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );
    RestContext.request.httpMethod = 'POST';

    Test.startTest();
    SalesReportLinkController.start();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    String linkUrl = (String) responseJson().get('linkUrl');
    Assert.isTrue(linkUrl.contains('/apex/SalesReport_Link?code='), linkUrl);
    String code = linkUrl.substringAfter('code=');
    SalesReport_Link_Code__c row = [
      SELECT Line_User_Id__c, Code_Hash__c
      FROM SalesReport_Link_Code__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      SalesReportTestFactory.LINE_USER_ID,
      row.Line_User_Id__c,
      'From the verified token'
    );
    Assert.areEqual(
      SalesReportLinkService.hash(EncodingUtil.urlDecode(code, 'UTF-8')),
      row.Code_Hash__c,
      'Same code'
    );
  }

  @IsTest
  static void startWithoutTokenCreatesNothing() {
    SalesReportTestFactory.settings();
    SalesReportTestFactory.meRequest(null, null);

    SalesReportLinkController.start();

    Assert.areEqual(401, RestContext.response.statusCode, 'Unauthorised');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM SalesReport_Link_Code__c WITH SYSTEM_MODE],
      'No code'
    );
  }
}
