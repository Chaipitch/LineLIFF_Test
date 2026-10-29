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
}
