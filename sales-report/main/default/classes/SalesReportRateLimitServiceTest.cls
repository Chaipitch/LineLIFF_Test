@IsTest
private class SalesReportRateLimitServiceTest {
  private static final String LINE_USER = SalesReportTestFactory.LINE_USER_ID;

  private static void limitTo(Integer perMinute) {
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Rate_Limit_Per_Minute__c = perMinute
    );
  }

  private static SalesReport_Rate_Limit__c row() {
    return [
      SELECT Window_Start__c, Request_Count__c
      FROM SalesReport_Rate_Limit__c
      WHERE Key__c = :SalesReportRateLimitService.keyFor(LINE_USER)
      WITH SYSTEM_MODE
    ];
  }

  @IsTest
  static void countsRequestsAndRefusesOverTheLimit() {
    limitTo(2);
    SalesReportRateLimitService.testNow = Datetime.newInstanceGmt(
      2026,
      10,
      30,
      9,
      15,
      42
    );

    for (Integer i = 0; i < 2; i++) {
      SalesReportRateLimitService.check(LINE_USER);
      SalesReportRateLimitService.flush();
    }
    SalesReportException refused;
    try {
      SalesReportRateLimitService.check(LINE_USER);
    } catch (SalesReportException e) {
      refused = e;
    }

    Assert.areEqual(2, row().Request_Count__c, 'Two counted');
    Assert.areEqual(
      Datetime.newInstanceGmt(2026, 10, 30, 9, 15, 0),
      row().Window_Start__c,
      'Minute window'
    );
    Assert.isNotNull(refused, 'Third request refused');
    Assert.areEqual(SalesReportException.RATE_LIMITED, refused.code, 'Code');
    Assert.areEqual(429, refused.statusCode, 'Status');
    SalesReportRateLimitService.flush();
    Assert.areEqual(2, row().Request_Count__c, 'Refused request not counted');
  }

  @IsTest
  static void newMinuteStartsAgain() {
    limitTo(1);
    SalesReportRateLimitService.testNow = Datetime.newInstanceGmt(
      2026,
      10,
      30,
      9,
      15,
      59
    );
    SalesReportRateLimitService.check(LINE_USER);
    SalesReportRateLimitService.flush();

    SalesReportRateLimitService.testNow = SalesReportRateLimitService.testNow.addSeconds(
      1
    );
    SalesReportRateLimitService.check(LINE_USER);
    SalesReportRateLimitService.flush();

    Assert.areEqual(1, row().Request_Count__c, 'Count reset');
    Assert.areEqual(
      Datetime.newInstanceGmt(2026, 10, 30, 9, 16, 0),
      row().Window_Start__c,
      'Next minute'
    );
  }

  @IsTest
  static void keyIsAHashNotTheLineUserId() {
    String key = SalesReportRateLimitService.keyFor(LINE_USER);
    Assert.areEqual(64, key.length(), 'SHA-256 hex');
    Assert.isFalse(key.contains(LINE_USER), 'No LINE user ID');
  }

  @IsTest
  static void blankUserAndEmptyFlushDoNothing() {
    SalesReportRateLimitService.check(' ');
    SalesReportRateLimitService.flush();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM SalesReport_Rate_Limit__c WITH SYSTEM_MODE],
      'Nothing written'
    );
  }

  @IsTest
  static void endpointAnswers429WhenOverTheLimit() {
    SalesReport_Settings__c settings = SalesReportTestFactory.settings();
    settings.Rate_Limit_Per_Minute__c = 1;
    update settings;
    SalesReportRateLimitService.testNow = Datetime.now();
    Database.insert(
      new SalesReport_Rate_Limit__c(
        Key__c = SalesReportRateLimitService.keyFor(LINE_USER),
        Window_Start__c = SalesReportRateLimitService.currentWindow(),
        Request_Count__c = 1
      ),
      AccessLevel.SYSTEM_MODE
    );
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    SalesReportTestFactory.meRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );

    Test.startTest();
    SalesReportMeController.getMe();
    Test.stopTest();

    Assert.areEqual(429, RestContext.response.statusCode, 'Too many');
    Assert.isTrue(
      RestContext.response.responseBody.toString()
        .contains(SalesReportException.RATE_LIMITED),
      'Error code'
    );
  }
}
