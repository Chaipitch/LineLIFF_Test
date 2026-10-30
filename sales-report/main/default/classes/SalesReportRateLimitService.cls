/**
 * Per-LINE-user rate limit (L7, D-14, D-36): at most Rate Limit per Minute requests per verified LINE user in each
 * calendar minute. check() runs right after the LINE token is verified and refuses with RATE_LIMITED (429); the count
 * is written by flush() at the end of the request, after all callouts (a callout after DML would fail).
 * Approximate under concurrency (two requests can read the same count), which is fine for abuse protection.
 *
 * `without sharing` with explicit SYSTEM_MODE (DATA-DICTIONARY §5.3, D-25): the counter is read and written for the
 * Site guest user, which has no object access by design. Only a SHA-256 of the LINE user ID is stored.
 */
public without sharing class SalesReportRateLimitService {
  private static SalesReport_Rate_Limit__c pending;
  /** Fixed clock for tests, so a test can't straddle a minute boundary. */
  @TestVisible
  private static Datetime testNow;

  public static void check(String lineUserId) {
    pending = null;
    if (String.isBlank(lineUserId)) {
      return;
    }
    String key = keyFor(lineUserId);
    Datetime window = currentWindow();
    List<SalesReport_Rate_Limit__c> rows = [
      SELECT Id, Window_Start__c, Request_Count__c
      FROM SalesReport_Rate_Limit__c
      WHERE Key__c = :key
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Integer count = 0;
    if (!rows.isEmpty() && rows[0].Window_Start__c == window) {
      count = rows[0].Request_Count__c == null
        ? 0
        : rows[0].Request_Count__c.intValue();
    }
    if (count >= SalesReportSettingsService.rateLimitPerMinute()) {
      throw SalesReportException.of(
        SalesReportException.RATE_LIMITED,
        429,
        'Too many requests from this LINE user; try again in a minute.'
      );
    }
    pending = new SalesReport_Rate_Limit__c(
      Key__c = key,
      Window_Start__c = window,
      Request_Count__c = count + 1
    );
  }

  /** Writes the counted request, if any. Never throws: a lost count must not break the response. */
  public static void flush() {
    if (pending == null) {
      return;
    }
    SalesReport_Rate_Limit__c row = pending;
    pending = null;
    try {
      Database.upsert(
        row,
        SalesReport_Rate_Limit__c.Key__c,
        false,
        AccessLevel.SYSTEM_MODE
      );
    } catch (Exception e) {
      SalesReportLogService.warn(
        'SalesReportRateLimitService.flush',
        e.getMessage()
      );
    }
  }

  @TestVisible
  static String keyFor(String lineUserId) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(lineUserId))
    );
  }

  @TestVisible
  static Datetime currentWindow() {
    Datetime now = testNow == null ? Datetime.now() : testNow;
    return Datetime.newInstanceGmt(
      now.yearGmt(),
      now.monthGmt(),
      now.dayGmt(),
      now.hourGmt(),
      now.minuteGmt(),
      0
    );
  }
}
