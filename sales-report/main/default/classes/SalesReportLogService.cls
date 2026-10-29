/**
 * Buffered application log (D-18). Entries are kept in memory and written by flush() in one insert, after any
 * callouts of the transaction. Logging never throws.
 *
 * `without sharing` and an explicit SYSTEM_MODE insert (DATA-DICTIONARY §5.3): logs must be written whoever the running
 * user is, including the Site guest user, which has no object or field access by design.
 *
 * Callers must never pass tokens, link codes, secrets or full LINE user IDs; use setLineUserRef() for correlation.
 */
public without sharing class SalesReportLogService {
  private static final Map<String, Integer> RANK = new Map<String, Integer>{
    'ERROR' => 0,
    'WARN' => 1,
    'INFO' => 2,
    'DEBUG' => 3
  };
  private static final Integer SOURCE_LENGTH = 255;
  private static final Integer MESSAGE_LENGTH = 32768;
  private static final Integer LINE_REF_LENGTH = 6;

  @TestVisible
  private static final List<SalesReport_Log__c> BUFFER = new List<SalesReport_Log__c>();
  private static String lineUserRef;

  public static void error(String source, String message) {
    add('ERROR', source, message);
  }

  public static void error(String source, Exception e) {
    add(
      'ERROR',
      source,
      e == null
        ? null
        : e.getTypeName() +
          ': ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
    );
  }

  public static void warn(String source, String message) {
    add('WARN', source, message);
  }

  public static void info(String source, String message) {
    add('INFO', source, message);
  }

  public static void debug(String source, String message) {
    add('DEBUG', source, message);
  }

  /** Keeps only the last characters of the verified LINE user ID on entries written from now on. */
  public static void setLineUserRef(String lineUserId) {
    lineUserRef = String.isBlank(lineUserId)
      ? null
      : lineUserId.right(LINE_REF_LENGTH);
  }

  public static void flush() {
    if (BUFFER.isEmpty()) {
      return;
    }
    try {
      Database.insert(BUFFER.clone(), false, AccessLevel.SYSTEM_MODE);
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'SalesReportLogService.flush failed: ' + e.getMessage()
      );
    } finally {
      BUFFER.clear();
    }
  }

  private static void add(String level, String source, String message) {
    try {
      if (RANK.get(level) > rankOf(SalesReportSettingsService.logLevel())) {
        return;
      }
      BUFFER.add(
        new SalesReport_Log__c(
          Level__c = level,
          Source__c = String.isBlank(source)
            ? 'unknown'
            : source.left(SOURCE_LENGTH),
          Message__c = message == null ? null : message.left(MESSAGE_LENGTH),
          Request_Id__c = Request.getCurrent().getRequestId(),
          User__c = UserInfo.getUserType() == 'Guest'
            ? null
            : UserInfo.getUserId(),
          Line_User_Ref__c = lineUserRef
        )
      );
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'SalesReportLogService.add failed: ' + e.getMessage()
      );
    }
  }

  private static Integer rankOf(String level) {
    Integer levelRank = RANK.get(level);
    return levelRank == null
      ? RANK.get(SalesReportSettingsService.DEFAULT_LOG_LEVEL)
      : levelRank;
  }
}
