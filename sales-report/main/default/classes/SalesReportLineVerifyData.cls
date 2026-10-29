/**
 * Success response of POST https://api.line.me/oauth2/v2.1/verify (ID token). Only the claims we use.
 */
public with sharing class SalesReportLineVerifyData {
  /** Issuer, https://access.line.me */
  public String iss;
  /** LINE user ID the token was issued for. */
  public String sub;
  /** LINE Login channel ID. */
  public String aud;
  /** Expiry, UNIX seconds. */
  public Long exp;
  /** Issued at, UNIX seconds. */
  public Long iat;
  /** Display name (profile scope). */
  public String name;
}
