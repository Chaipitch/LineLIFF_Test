/**
 * Single reader of SalesReport_Settings__c (org defaults). Blank fields fall back to the defaults below, so the
 * feature works with no settings record except for the values that must come from the admin (channel ID, LIFF ID).
 */
public with sharing class SalesReportSettingsService {
  public static final String DEFAULT_LOG_LEVEL = 'WARN';
  public static final String DEFAULT_JWT_CERTIFICATE = 'SalesReport_JWT_Signing';
  @TestVisible
  static final Integer DEFAULT_LINK_CODE_TTL_MINUTES = 5;
  @TestVisible
  static final Integer MAX_LINK_CODE_TTL_MINUTES = 30;
  @TestVisible
  static final Integer DEFAULT_SEARCH_MIN_CHARS = 2;
  @TestVisible
  static final Integer DEFAULT_SEARCH_MAX_RESULTS = 10;
  @TestVisible
  static final Integer MAX_SEARCH_RESULTS = 50;

  @TestVisible
  private static SalesReport_Settings__c cached;

  public static String lineLoginChannelId() {
    return trimToNull(settings().Line_Login_Channel_Id__c);
  }

  public static String liffId() {
    return trimToNull(settings().Liff_Id__c);
  }

  /** No settings record means enabled; otherwise the admin's checkbox decides. */
  public static Boolean isEnabled() {
    SalesReport_Settings__c s = settings();
    return s.Id == null || s.Enabled__c == true;
  }

  public static String ecaConsumerKey() {
    return trimToNull(settings().Eca_Consumer_Key__c);
  }

  public static String jwtCertificateName() {
    String name = trimToNull(settings().Jwt_Certificate_Name__c);
    return name == null ? DEFAULT_JWT_CERTIFICATE : name;
  }

  /** Between 1 and MAX_LINK_CODE_TTL_MINUTES; blank = DEFAULT_LINK_CODE_TTL_MINUTES. */
  public static Integer linkCodeTtlMinutes() {
    Decimal minutes = settings().Link_Code_Ttl_Minutes__c;
    if (minutes == null || minutes < 1) {
      return DEFAULT_LINK_CODE_TTL_MINUTES;
    }
    return Math.min(minutes.intValue(), MAX_LINK_CODE_TTL_MINUTES);
  }

  /** Between 1 and 10; blank = DEFAULT_SEARCH_MIN_CHARS. */
  public static Integer accountSearchMinChars() {
    return bounded(
      settings().Account_Search_Min_Chars__c,
      DEFAULT_SEARCH_MIN_CHARS,
      10
    );
  }

  /** Between 1 and MAX_SEARCH_RESULTS; blank = DEFAULT_SEARCH_MAX_RESULTS. */
  public static Integer accountSearchMaxResults() {
    return bounded(
      settings().Account_Search_Max_Results__c,
      DEFAULT_SEARCH_MAX_RESULTS,
      MAX_SEARCH_RESULTS
    );
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

  private static Integer bounded(Decimal value, Integer fallback, Integer max) {
    if (value == null || value < 1) {
      return fallback;
    }
    return Math.min(value.intValue(), max);
  }

  private static String trimToNull(String value) {
    return String.isBlank(value) ? null : value.trim();
  }
}
