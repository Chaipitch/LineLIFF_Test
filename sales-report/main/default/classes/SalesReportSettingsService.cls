/**
 * Single reader of SalesReport_Settings__c (org defaults). The setting holds only what differs per environment or what
 * an admin switches (D-48): LINE Login channel ID, LIFF ID, External Client App consumer key, certificate name, the two
 * form switches and the log level / retention. Everything else is a fixed value below (tests may change the
 * @TestVisible ones). Blank fields fall back to the defaults.
 */
public with sharing class SalesReportSettingsService {
  public static final String DEFAULT_LOG_LEVEL = 'WARN';
  public static final String DEFAULT_JWT_CERTIFICATE = 'SalesReport_JWT_Signing';
  @TestVisible
  static final Integer DEFAULT_LOG_RETENTION_DAYS = 30;
  @TestVisible
  static final Integer MAX_LOG_RETENTION_DAYS = 365;
  /** Fixed values (were settings until D-48). */
  @TestVisible
  static Integer linkCodeTtl = 5;
  @TestVisible
  static Integer searchMinChars = 2;
  @TestVisible
  static Integer searchMaxResults = 10;
  @TestVisible
  static Integer maxFilesPerActivity = 5;
  /** Also the hard cap: a 4 MB file peaks at ~5.6 MB of the 6 MB Apex heap on its way to the API (D-34). */
  @TestVisible
  static Integer maxFileSizeMb = 4;
  @TestVisible
  static final List<String> FILE_TYPES = new List<String>{
    'jpg',
    'jpeg',
    'png',
    'pdf'
  };
  @TestVisible
  static Integer requestsPerMinute = 60;

  @TestVisible
  private static SalesReport_Settings__c cached;

  public static String lineLoginChannelId() {
    return trimToNull(settings().Line_Login_Channel_Id__c);
  }

  public static String liffId() {
    return trimToNull(settings().Liff_Id__c);
  }

  public static String ecaConsumerKey() {
    return trimToNull(settings().Eca_Consumer_Key__c);
  }

  public static String jwtCertificateName() {
    String name = trimToNull(settings().Jwt_Certificate_Name__c);
    return name == null ? DEFAULT_JWT_CERTIFICATE : name;
  }

  /** Minutes a one-time link code stays valid. */
  public static Integer linkCodeTtlMinutes() {
    return linkCodeTtl;
  }

  /** Characters before a search starts (Accounts, lookup fields). */
  public static Integer accountSearchMinChars() {
    return searchMinChars;
  }

  /** Accounts shown in the search list. */
  public static Integer accountSearchMaxResults() {
    return searchMaxResults;
  }

  /** Attachments on Log Activity: off unless an admin ticks Attachments Enabled. */
  public static Boolean attachmentsEnabled() {
    return settings().Attachments_Enabled__c == true;
  }

  public static Integer attachmentMaxFiles() {
    return maxFilesPerActivity;
  }

  public static Integer attachmentMaxSizeMb() {
    return maxFileSizeMb;
  }

  /** Allowed file extensions, lower case without dots. */
  public static List<String> attachmentFileTypes() {
    return new List<String>(FILE_TYPES);
  }

  /** Requests per LINE user per minute. */
  public static Integer rateLimitPerMinute() {
    return requestsPerMinute;
  }

  /** Days logs are kept, between 1 and MAX_LOG_RETENTION_DAYS; blank = DEFAULT_LOG_RETENTION_DAYS. */
  public static Integer logRetentionDays() {
    Decimal days = settings().Log_Retention_Days__c;
    if (days == null || days < 1) {
      return DEFAULT_LOG_RETENTION_DAYS;
    }
    return Math.min(days.intValue(), MAX_LOG_RETENTION_DAYS);
  }

  /** Update Opportunity in LINE: off unless an admin ticks Update Opportunity Enabled. */
  public static Boolean opportunityFormEnabled() {
    return settings().Opportunity_Form_Enabled__c == true;
  }

  public static String logLevel() {
    String level = trimToNull(settings().Log_Level__c);
    return level == null ? DEFAULT_LOG_LEVEL : level.toUpperCase();
  }

  private static SalesReport_Settings__c settings() {
    if (cached == null) {
      cached = SalesReport_Settings__c.getOrgDefaults();
      if (cached == null) {
        cached = new SalesReport_Settings__c();
      }
    }
    return cached;
  }

  private static String trimToNull(String value) {
    return String.isBlank(value) ? null : value.trim();
  }
}
