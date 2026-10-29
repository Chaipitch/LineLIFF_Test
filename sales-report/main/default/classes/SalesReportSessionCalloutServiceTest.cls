@IsTest
private class SalesReportSessionCalloutServiceTest {
  private static SalesReportException exchangeExpectingFailure() {
    try {
      new SalesReportSessionCalloutService()
        .accessTokenFor(UserInfo.getUserName());
    } catch (SalesReportException e) {
      return e;
    }
    Assert.fail('Expected a SalesReportException');
    return null;
  }

  @IsTest
  static void missingConsumerKeyIsConfigError() {
    SalesReportTestFactory.settings();
    SalesReportSessionCalloutService.testAccessToken = 'never-used';

    SalesReportException e = exchangeExpectingFailure();

    Assert.areEqual(
      SalesReportException.CONFIG_MISSING,
      e.code,
      'Consumer key required'
    );
    Assert.areEqual(503, e.statusCode, 'Status');
  }

  @IsTest
  static void testTokenIsReturnedWhenConfigured() {
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Eca_Consumer_Key__c = 'test-consumer-key'
    );
    SalesReportSessionCalloutService.testAccessToken = 'session-token';

    String token = new SalesReportSessionCalloutService()
      .accessTokenFor(UserInfo.getUserName());

    Assert.areEqual('session-token', token, 'Token for the rep');
  }

  @IsTest
  static void unknownCertificateFailsCleanly() {
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Eca_Consumer_Key__c = 'test-consumer-key',
      Jwt_Certificate_Name__c = 'No_Such_Certificate_' +
        Crypto.getRandomInteger()
    );
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(400, '{"error":"invalid_grant"}')
    );

    SalesReportException e = exchangeExpectingFailure();

    Assert.isTrue(
      e.code == SalesReportException.CONFIG_MISSING ||
        e.code == SalesReportException.NOT_AUTHORIZED,
      'Mapped to a known code: ' + e.code
    );
  }

  @IsTest
  static void audienceAndEndpointFollowTheOrg() {
    Boolean sandbox = [SELECT IsSandbox FROM Organization].IsSandbox;
    Assert.areEqual(
      sandbox
        ? SalesReportSessionCalloutService.SANDBOX_AUDIENCE
        : SalesReportSessionCalloutService.PRODUCTION_AUDIENCE,
      SalesReportSessionCalloutService.audience(),
      'Audience'
    );
    Assert.areEqual(
      URL.getOrgDomainUrl().toExternalForm() + '/services/oauth2/token',
      SalesReportSessionCalloutService.tokenEndpoint(),
      'Own My Domain'
    );
  }
}
