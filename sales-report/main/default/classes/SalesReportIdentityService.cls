/**
 * Who is calling? Reads the LINE ID token from the request header, verifies it with LINE and returns the verified
 * claims. Never trusts a LINE user ID sent as data. repSession() goes on to the linked rep and a Salesforce session of
 * that rep (Option B) for endpoints that read or write business data.
 */
public with sharing class SalesReportIdentityService {
  /** Not `Authorization`: Salesforce would treat a bearer token there as a Salesforce session and reject it. */
  public static final String TOKEN_HEADER = 'X-Line-Id-Token';
  @TestVisible
  static final Integer MAX_TOKEN_LENGTH = 4096;

  public SalesReportLineVerifyData identify(RestRequest req) {
    if (!SalesReportSettingsService.isEnabled()) {
      throw SalesReportException.of(
        SalesReportException.UNAVAILABLE,
        503,
        'Sales Report is switched off in settings.'
      );
    }
    String channelId = SalesReportSettingsService.lineLoginChannelId();
    if (channelId == null) {
      throw SalesReportException.of(
        SalesReportException.CONFIG_MISSING,
        503,
        'Sales Report Settings: LINE Login Channel ID is not set.'
      );
    }
    String token = header(req, TOKEN_HEADER);
    if (String.isBlank(token)) {
      throw SalesReportException.of(
        SalesReportException.TOKEN_MISSING,
        401,
        'No LINE ID token was sent.'
      );
    }
    if (token.length() > MAX_TOKEN_LENGTH) {
      throw SalesReportException.of(
        SalesReportException.TOKEN_INVALID,
        401,
        'The LINE ID token is not valid.'
      );
    }

    SalesReportLineVerifyData identity = new SalesReportLineCalloutService()
      .verifyIdToken(token.trim(), channelId);
    SalesReportLogService.setLineUserRef(identity.sub);
    return identity;
  }

  /** Header names are case-insensitive in HTTP; RestRequest.headers is not. */
  private static String header(RestRequest req, String name) {
    if (req == null || req.headers == null) {
      return null;
    }
    for (String key : req.headers.keySet()) {
      if (key != null && key.equalsIgnoreCase(name)) {
        return req.headers.get(key);
      }
    }
    return null;
  }

  /**
   * Verified LINE user → active link → org API client acting as the linked rep. Callout order: LINE verify, link
   * lookup (no DML while the link is active), JWT exchange. Not linked (or the user was deactivated) → NOT_LINKED,
   * and the LIFF page shows "Connect Salesforce" again.
   */
  public SalesReportOrgApiCalloutService repSession(RestRequest req) {
    SalesReportLineVerifyData identity = identify(req);
    SalesReport_Line_Link__c link = new SalesReportLinkService()
      .findActiveLink(identity.sub);
    if (link == null) {
      throw SalesReportException.of(
        SalesReportException.NOT_LINKED,
        403,
        'This LINE account is not connected to Salesforce.'
      );
    }
    String accessToken = new SalesReportSessionCalloutService()
      .accessTokenFor(link.User__r.Username);
    return new SalesReportOrgApiCalloutService(
      accessToken,
      link.User__r.TimeZoneSidKey,
      link.User__c
    );
  }
}
