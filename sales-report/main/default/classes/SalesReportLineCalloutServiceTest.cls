@IsTest
private class SalesReportLineCalloutServiceTest {
  private static SalesReportException verifyExpectingFailure(
    SalesReportHttpMock mock
  ) {
    Test.setMock(HttpCalloutMock.class, mock);
    try {
      new SalesReportLineCalloutService()
        .verifyIdToken(
          SalesReportTestFactory.ID_TOKEN,
          SalesReportTestFactory.CHANNEL_ID
        );
    } catch (SalesReportException e) {
      return e;
    }
    Assert.fail('Expected a SalesReportException');
    return null;
  }

  @IsTest
  static void validTokenReturnsClaimsAndSendsFormRequest() {
    SalesReportHttpMock mock = new SalesReportHttpMock(
      200,
      SalesReportTestFactory.verifyBody()
    );
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportLineVerifyData data = new SalesReportLineCalloutService()
      .verifyIdToken('a+b/c=', SalesReportTestFactory.CHANNEL_ID);
    Test.stopTest();

    Assert.areEqual(SalesReportTestFactory.LINE_USER_ID, data.sub, 'sub');
    Assert.areEqual(SalesReportTestFactory.DISPLAY_NAME, data.name, 'name');
    Assert.areEqual(
      SalesReportLineCalloutService.VERIFY_ENDPOINT,
      mock.lastRequest.getEndpoint(),
      'Endpoint'
    );
    Assert.areEqual('POST', mock.lastRequest.getMethod(), 'Method');
    Assert.areEqual(
      'application/x-www-form-urlencoded',
      mock.lastRequest.getHeader('Content-Type'),
      'Form-encoded body'
    );
    Assert.areEqual(
      'id_token=a%2Bb%2Fc%3D&client_id=' + SalesReportTestFactory.CHANNEL_ID,
      mock.lastRequest.getBody(),
      'Token and channel ID are URL-encoded'
    );
  }

  @IsTest
  static void expiredTokenFromLine() {
    SalesReportException e = verifyExpectingFailure(
      new SalesReportHttpMock(
        400,
        SalesReportTestFactory.lineError(
          SalesReportLineCalloutService.EXPIRED_DESCRIPTION
        )
      )
    );
    Assert.areEqual(SalesReportException.TOKEN_EXPIRED, e.code, 'Expired');
    Assert.areEqual(401, e.statusCode, 'Status');
  }

  @IsTest
  static void otherLineRejectionIsInvalid() {
    SalesReportException e = verifyExpectingFailure(
      new SalesReportHttpMock(
        400,
        SalesReportTestFactory.lineError('Invalid IdToken Audience.')
      )
    );
    Assert.areEqual(SalesReportException.TOKEN_INVALID, e.code, 'Invalid');
  }

  @IsTest
  static void unreadableErrorBodyIsInvalid() {
    SalesReportException e = verifyExpectingFailure(
      new SalesReportHttpMock(400, 'not json')
    );
    Assert.areEqual(SalesReportException.TOKEN_INVALID, e.code, 'Invalid');
  }

  @IsTest
  static void wrongAudienceIsInvalid() {
    SalesReportException e = verifyExpectingFailure(
      new SalesReportHttpMock(
        200,
        SalesReportTestFactory.verifyBody(
          '9999999999',
          'https://access.line.me',
          3600
        )
      )
    );
    Assert.areEqual(SalesReportException.TOKEN_INVALID, e.code, 'aud mismatch');
  }

  @IsTest
  static void wrongIssuerIsInvalid() {
    SalesReportException e = verifyExpectingFailure(
      new SalesReportHttpMock(
        200,
        SalesReportTestFactory.verifyBody(
          SalesReportTestFactory.CHANNEL_ID,
          'https://evil.example',
          3600
        )
      )
    );
    Assert.areEqual(SalesReportException.TOKEN_INVALID, e.code, 'iss mismatch');
  }

  @IsTest
  static void pastExpiryIsExpired() {
    SalesReportException e = verifyExpectingFailure(
      new SalesReportHttpMock(
        200,
        SalesReportTestFactory.verifyBody(
          SalesReportTestFactory.CHANNEL_ID,
          'https://access.line.me',
          -10
        )
      )
    );
    Assert.areEqual(
      SalesReportException.TOKEN_EXPIRED,
      e.code,
      'exp in the past'
    );
  }

  @IsTest
  static void unreadableSuccessBodyIsLineError() {
    SalesReportException e = verifyExpectingFailure(
      new SalesReportHttpMock(200, '{not json')
    );
    Assert.areEqual(SalesReportException.LINE_ERROR, e.code, 'Bad JSON');
    Assert.areEqual(502, e.statusCode, 'Status');
  }

  @IsTest
  static void serverErrorIsLineError() {
    SalesReportException e = verifyExpectingFailure(
      new SalesReportHttpMock(500, '{}')
    );
    Assert.areEqual(SalesReportException.LINE_ERROR, e.code, 'HTTP 500');
  }

  @IsTest
  static void calloutFailureIsLineError() {
    SalesReportException e = verifyExpectingFailure(
      SalesReportHttpMock.unreachable()
    );
    Assert.areEqual(SalesReportException.LINE_ERROR, e.code, 'Unreachable');
  }
}
