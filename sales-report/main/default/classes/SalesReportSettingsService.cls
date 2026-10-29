/**
 * Single reader of SalesReport_Settings__c (org defaults). Blank fields fall back to the defaults below, so the
 * feature works with no settings record except for the values that must come from the admin (channel ID, LIFF ID).
 */
public with sharing class SalesReportSettingsService {
  public static final String DEFAULT_LOG_LEVEL = 'WARN';

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
