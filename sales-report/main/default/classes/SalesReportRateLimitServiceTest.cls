@IsTest
private class SalesReportRateLimitServiceTest {
  private static final String LINE_USER = SalesReportTestFactory.LINE_USER_ID;

  /** Counters in memory: Platform Cache is shared across tests and not rolled back. */
  private static SalesReportRateLimitService.MemoryStore memory() {
    SalesReportRateLimitService.MemoryStore store = new SalesReportRateLimitService.MemoryStore();
    SalesReportRateLimitService.store = store;
    return store;
  }

  private static List<Object> counter(
    SalesReportRateLimitService.MemoryStore store
  ) {
    return (List<Object>) store.values.get(
      SalesReportRateLimitService.keyFor(LINE_USER)
    );
  }

  @IsTest
  static void countsRequestsAndRefusesOverTheLimit() {
    SalesReportRateLimitService.MemoryStore store = memory();
    SalesReportSettingsService.requestsPerMinute = 2;
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

    Assert.areEqual(2, counter(store)[1], 'Two counted');
    Assert.areEqual(
      SalesReportRateLimitService.currentMinute(),
      counter(store)[0],
      'Minute window'
    );
    Assert.isNotNull(refused, 'Third request refused');
    Assert.areEqual(SalesReportException.RATE_LIMITED, refused.code, 'Code');
    Assert.areEqual(429, refused.statusCode, 'Status');
    SalesReportRateLimitService.flush();
    Assert.areEqual(2, counter(store)[1], 'Refused request not counted');
  }

  @IsTest
  static void newMinuteStartsAgain() {
    SalesReportRateLimitService.MemoryStore store = memory();
    SalesReportSettingsService.requestsPerMinute = 1;
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

    Assert.areEqual(1, counter(store)[1], 'Count reset');
  }

  @IsTest
  static void keyIsShortAlphanumericAndHidesTheLineUserId() {
    String key = SalesReportRateLimitService.keyFor(LINE_USER);
    Assert.areEqual(42, key.length(), 'rl + 40 hex');
    Assert.isTrue(key.isAlphanumeric(), 'Cache keys are alphanumeric');
    Assert.isFalse(key.contains(LINE_USER), 'No LINE user ID');
  }

  @IsTest
  static void blankUserAndEmptyFlushDoNothing() {
    SalesReportRateLimitService.MemoryStore store = memory();
    SalesReportRateLimitService.check(' ');
    SalesReportRateLimitService.flush();
    Assert.isTrue(store.values.isEmpty(), 'Nothing written');
  }

  @IsTest
  static void brokenCacheNeverBlocksTheRequest() {
    SalesReportRateLimitService.store = new FailingStore();
    SalesReportSettingsService.requestsPerMinute = 1;

    SalesReportRateLimitService.check(LINE_USER);
    SalesReportRateLimitService.flush();
    SalesReportRateLimitService.check(LINE_USER);
    SalesReportRateLimitService.flush();

    SalesReportLogService.flush();
    Assert.isTrue(
      [SELECT COUNT() FROM SalesReport_Log__c WITH SYSTEM_MODE] > 0,
      'Cache problems are logged as WARN, never thrown'
    );
  }

  @IsTest
  static void realCacheRoundTripDoesNotThrow() {
    // Uses the real partition; with no capacity the value is simply not kept (fail open).
    // A random LINE user, so other runs can't have counted it. Limit 1: the second request is refused when the
    // cache kept the count, and allowed when it didn't — either way, nothing else may go wrong.
    String lineUser =
      'U' + EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    SalesReportSettingsService.requestsPerMinute = 1;
    SalesReportRateLimitService.check(lineUser);
    SalesReportRateLimitService.flush();
    String outcome = 'allowed';
    try {
      SalesReportRateLimitService.check(lineUser);
    } catch (SalesReportException e) {
      outcome = e.code;
    }
    Assert.isTrue(
      outcome == 'allowed' || outcome == SalesReportException.RATE_LIMITED,
      outcome
    );
  }

  @IsTest
  static void endpointAnswers429WhenOverTheLimit() {
    SalesReportRateLimitService.MemoryStore store = memory();
    SalesReportTestFactory.settings();
    SalesReportSettingsService.requestsPerMinute = 1;
    SalesReportRateLimitService.testNow = Datetime.now();
    store.values.put(
      SalesReportRateLimitService.keyFor(LINE_USER),
      new List<Object>{ SalesReportRateLimitService.currentMinute(), 1 }
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

    Assert.areEqual(429, RestContext.response.statusCode, 'Too many');
    Assert.isTrue(
      RestContext.response.responseBody.toString()
        .contains(SalesReportException.RATE_LIMITED),
      'Error code'
    );
  }

  private class FailingStore implements SalesReportRateLimitService.Store {
    public Object get(String key) {
      throw new NullPointerException();
    }

    public void put(String key, Object value, Integer ttlSeconds) {
      throw new NullPointerException();
    }
  }
}
