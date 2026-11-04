/**
 * Per-LINE-user rate limit (L7, D-36, D-51): at most rateLimitPerMinute() requests per verified LINE user in each
 * calendar minute. check() runs right after the LINE token is verified and refuses with RATE_LIMITED (429); the count
 * is written by flush() at the end of the request. Approximate under concurrency (two requests can read the same
 * count), which is fine for abuse protection.
 *
 * The counter lives in Platform Cache, partition SalesReportCache (org cache, 1 MB): key "rl" + 40 hex characters of
 * the SHA-256 of the LINE user ID (the LINE user ID itself is never stored), value [minute, count], kept 5 minutes
 * (the cache's minimum) so it expires on its own — no cleanup job. If the cache is unavailable or drops the entry,
 * the request is simply not limited: the limit is a safety net and must never block reps.
 */
public with sharing class SalesReportRateLimitService {
  @TestVisible
  static final String PARTITION = 'SalesReportCache';
  /** Seconds a counter is kept: Platform Cache's minimum time-to-live. */
  @TestVisible
  static final Integer TTL_SECONDS = 300;
  private static final String KEY_PREFIX = 'rl';
  private static final String SOURCE = 'SalesReportRateLimitService';

  /** Where counters are kept: Platform Cache, or a map in tests (the cache is shared and not rolled back). */
  @TestVisible
  private static Store store = new CacheStore();
  private static String pendingKey;
  private static List<Object> pendingValue;
  /** Fixed clock for tests, so a test can't straddle a minute boundary. */
  @TestVisible
  private static Datetime testNow;

  public static void check(String lineUserId) {
    pendingKey = null;
    pendingValue = null;
    if (String.isBlank(lineUserId)) {
      return;
    }
    String key = keyFor(lineUserId);
    Long minute = currentMinute();
    Integer count = 0;
    Object stored = safeGet(key);
    if (stored instanceof List<Object>) {
      List<Object> entry = (List<Object>) stored;
      if (
        entry.size() == 2 &&
        entry[0] instanceof Long &&
        (Long) entry[0] == minute &&
        entry[1] instanceof Integer
      ) {
        count = (Integer) entry[1];
      }
    }
    if (count >= SalesReportSettingsService.rateLimitPerMinute()) {
      throw SalesReportException.of(
        SalesReportException.RATE_LIMITED,
        429,
        'Too many requests from this LINE user; try again in a minute.'
      );
    }
    pendingKey = key;
    pendingValue = new List<Object>{ minute, count + 1 };
  }

  /** Writes the counted request, if any. Never throws: a lost count must not break the response. */
  public static void flush() {
    if (pendingKey == null) {
      return;
    }
    String key = pendingKey;
    List<Object> value = pendingValue;
    pendingKey = null;
    pendingValue = null;
    try {
      store.put(key, value, TTL_SECONDS);
    } catch (Exception e) {
      SalesReportLogService.warn(SOURCE + '.flush', e.getMessage());
    }
  }

  /** Cache key: alphanumeric, at most 50 characters, no LINE user ID in it. */
  @TestVisible
  static String keyFor(String lineUserId) {
    return KEY_PREFIX +
      EncodingUtil.convertToHex(
          Crypto.generateDigest('SHA-256', Blob.valueOf(lineUserId))
        )
        .left(40);
  }

  /** Minutes since 1970 (UTC): one counting window per calendar minute. */
  @TestVisible
  static Long currentMinute() {
    Datetime now = testNow == null ? Datetime.now() : testNow;
    return now.getTime() / 60000;
  }

  private static Object safeGet(String key) {
    try {
      return store.get(key);
    } catch (Exception e) {
      SalesReportLogService.warn(SOURCE + '.check', e.getMessage());
      return null;
    }
  }

  @TestVisible
  interface Store {
    Object get(String key);
    void put(String key, Object value, Integer ttlSeconds);
  }

  /** Platform Cache org partition, namespace-safe ("local" when unpackaged). */
  @TestVisible
  class CacheStore implements Store {
    private Cache.OrgPartition partition() {
      String namespace = SalesReportNamespaceService.namespace();
      return Cache.Org.getPartition(
        (String.isBlank(namespace) ? 'local' : namespace) + '.' + PARTITION
      );
    }

    public Object get(String key) {
      return partition().get(key);
    }

    public void put(String key, Object value, Integer ttlSeconds) {
      partition().put(key, value, ttlSeconds);
    }
  }

  /** In-memory store for tests. */
  @TestVisible
  class MemoryStore implements Store {
    public final Map<String, Object> values = new Map<String, Object>();

    public Object get(String key) {
      return values.get(key);
    }

    public void put(String key, Object value, Integer ttlSeconds) {
      values.put(key, value);
    }
  }
}
