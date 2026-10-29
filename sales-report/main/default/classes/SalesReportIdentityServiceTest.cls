@IsTest
private class SalesReportIdentityServiceTest {
  private static SalesReportException identifyExpectingFailure(
    RestRequest req
  ) {
    try {
      new SalesReportIdentityService().identify(req);
    } catch (SalesReportException e) {
      return e;
    }
    Assert.fail('Expected a SalesReportException');
    return null;
  }

  @IsTest
  static void verifiesTokenFromHeaderCaseInsensitively() {
    SalesReportTestFactory.settings();
    SalesReportHttpMock mock = new SalesReportHttpMock(
      200,
      SalesReportTestFactory.verifyBody()
    );
    Test.setMock(HttpCalloutMock.class, mock);
    RestRequest req = SalesReportTestFactory.meRequest(
      'x-line-id-token',
      SalesReportTestFactory.ID_TOKEN
    );

    Test.startTest();
    SalesReportLineVerifyData identity = new SalesReportIdentityService()
      .identify(req);
    Test.stopTest();

    Assert.areEqual(
      SalesReportTestFactory.LINE_USER_ID,
      identity.sub,
      'Verified LINE user'
    );
    Assert.isTrue(
      mock.lastRequest.getBody()
        .contains('client_id=' + SalesReportTestFactory.CHANNEL_ID),
      'Channel ID'
    );
  }

  @IsTest
  static void switchedOff() {
    SalesReportTestFactory.settings(false, 'WARN');
    SalesReportException e = identifyExpectingFailure(
      SalesReportTestFactory.meRequest(
        SalesReportIdentityService.TOKEN_HEADER,
        SalesReportTestFactory.ID_TOKEN
      )
    );
    Assert.areEqual(SalesReportException.UNAVAILABLE, e.code, 'Kill switch');
    Assert.areEqual(503, e.statusCode, 'Status');
  }

  @IsTest
  static void missingChannelId() {
    SalesReportException e = identifyExpectingFailure(
      SalesReportTestFactory.meRequest(
        SalesReportIdentityService.TOKEN_HEADER,
        SalesReportTestFactory.ID_TOKEN
      )
    );
    Assert.areEqual(SalesReportException.CONFIG_MISSING, e.code, 'No settings');
  }

  @IsTest
  static void missingToken() {
    SalesReportTestFactory.settings();
    SalesReportException e = identifyExpectingFailure(
      SalesReportTestFactory.meRequest(null, null)
    );
    Assert.areEqual(SalesReportException.TOKEN_MISSING, e.code, 'No header');
    Assert.areEqual(401, e.statusCode, 'Status');
  }

  @IsTest
  static void nullRequestHasNoToken() {
    SalesReportTestFactory.settings();
    SalesReportException e = identifyExpectingFailure(null);
    Assert.areEqual(SalesReportException.TOKEN_MISSING, e.code, 'No request');
  }

  @IsTest
  static void oversizedTokenIsRejectedWithoutCallout() {
    SalesReportTestFactory.settings();
    SalesReportException e = identifyExpectingFailure(
      SalesReportTestFactory.meRequest(
        SalesReportIdentityService.TOKEN_HEADER,
        'x'.repeat(SalesReportIdentityService.MAX_TOKEN_LENGTH + 1)
      )
    );
    Assert.areEqual(SalesReportException.TOKEN_INVALID, e.code, 'Too long');
  }
}
