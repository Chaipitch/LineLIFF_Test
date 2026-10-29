/**
 * Option B (D-02): a short-lived Salesforce access token for the linked rep, via the OAuth 2.0 JWT bearer flow of the
 * External Client App SalesReport_App, signed with the certificate from settings. The token is used for the current
 * request only and never stored or logged (D-16).
 */
public with sharing class SalesReportSessionCalloutService {
  @TestVisible
  static final String SANDBOX_AUDIENCE = 'https://test.salesforce.com';
  @TestVisible
  static final String PRODUCTION_AUDIENCE = 'https://login.salesforce.com';
  private static final Integer JWT_VALIDITY_SECONDS = 180;

  /** Tests set this instead of a real exchange (needs a certificate and an External Client App in the org). */
  @TestVisible
  private static String testAccessToken;

  public String accessTokenFor(String username) {
    String consumerKey = SalesReportSettingsService.ecaConsumerKey();
    if (consumerKey == null) {
      throw SalesReportException.of(
        SalesReportException.CONFIG_MISSING,
        503,
        'Sales Report Settings: ECA Consumer Key is not set.'
      );
    }
    if (Test.isRunningTest() && testAccessToken != null) {
      return testAccessToken;
    }

    Auth.JWTBearerTokenExchange exchange;
    try {
      Auth.JWT jwt = new Auth.JWT();
      jwt.setSub(username);
      jwt.setAud(audience());
      jwt.setIss(consumerKey);
      jwt.setValidityLength(JWT_VALIDITY_SECONDS);
      Auth.JWS jws = new Auth.JWS(
        jwt,
        SalesReportSettingsService.jwtCertificateName()
      );
      exchange = new Auth.JWTBearerTokenExchange(tokenEndpoint(), jws);
    } catch (Exception e) {
      throw SalesReportException.of(
        SalesReportException.CONFIG_MISSING,
        503,
        'Could not sign the JWT (certificate ' +
          SalesReportSettingsService.jwtCertificateName() +
          '): ' +
          e.getMessage()
      );
    }
    try {
      return exchange.getAccessToken();
    } catch (Exception e) {
      throw SalesReportException.of(
        SalesReportException.NOT_AUTHORIZED,
        403,
        'Salesforce refused a session for this user (is the user active and assigned Sales Report User?): ' +
        e.getMessage()
      );
    }
  }

  @TestVisible
  static String audience() {
    Boolean sandbox = [
      SELECT IsSandbox
      FROM Organization
      WITH SYSTEM_MODE
      LIMIT 1
    ]
    .IsSandbox;
    return sandbox ? SANDBOX_AUDIENCE : PRODUCTION_AUDIENCE;
  }

  @TestVisible
  static String tokenEndpoint() {
    return URL.getOrgDomainUrl().toExternalForm() + '/services/oauth2/token';
  }
}
