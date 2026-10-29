/**
 * LINE Platform callouts. Today: ID-token verification (LINE Login v2.1, POST /oauth2/v2.1/verify).
 * The endpoint checks signature, issuer, audience and expiry; the claims are re-checked here defensively.
 * The token itself is never logged or returned.
 */
public with sharing class SalesReportLineCalloutService {
  @TestVisible
  static final String VERIFY_ENDPOINT = 'https://api.line.me/oauth2/v2.1/verify';
  @TestVisible
  static final String EXPECTED_ISSUER = 'https://access.line.me';
  @TestVisible
  static final String EXPIRED_DESCRIPTION = 'IdToken expired.';
  private static final Integer TIMEOUT_MS = 10000;

  public SalesReportLineVerifyData verifyIdToken(
    String idToken,
    String channelId
  ) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(VERIFY_ENDPOINT);
    req.setMethod('POST');
    req.setTimeout(TIMEOUT_MS);
    req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
    req.setBody(
      'id_token=' +
        EncodingUtil.urlEncode(idToken, 'UTF-8') +
        '&client_id=' +
        EncodingUtil.urlEncode(channelId, 'UTF-8')
    );

    HttpResponse res;
    try {
      res = new Http().send(req);
    } catch (CalloutException e) {
      throw SalesReportException.of(
        SalesReportException.LINE_ERROR,
        502,
        'Could not reach LINE: ' + e.getMessage()
      );
    }

    Integer status = res.getStatusCode();
    if (status == 200) {
      return validated(parse(res.getBody()), channelId);
    }
    if (status == 400) {
      if (errorDescription(res.getBody()) == EXPIRED_DESCRIPTION) {
        throw SalesReportException.of(
          SalesReportException.TOKEN_EXPIRED,
          401,
          'The LINE ID token has expired.'
        );
      }
      throw SalesReportException.of(
        SalesReportException.TOKEN_INVALID,
        401,
        'The LINE ID token is not valid.'
      );
    }
    throw SalesReportException.of(
      SalesReportException.LINE_ERROR,
      502,
      'LINE verify answered HTTP ' + status + '.'
    );
  }

  private static SalesReportLineVerifyData validated(
    SalesReportLineVerifyData data,
    String channelId
  ) {
    if (
      data == null ||
      String.isBlank(data.sub) ||
      data.aud != channelId ||
      data.iss != EXPECTED_ISSUER
    ) {
      throw SalesReportException.of(
        SalesReportException.TOKEN_INVALID,
        401,
        'The LINE ID token is not valid.'
      );
    }
    if (data.exp == null || data.exp * 1000 <= Datetime.now().getTime()) {
      throw SalesReportException.of(
        SalesReportException.TOKEN_EXPIRED,
        401,
        'The LINE ID token has expired.'
      );
    }
    return data;
  }

  private static SalesReportLineVerifyData parse(String body) {
    try {
      return (SalesReportLineVerifyData) JSON.deserialize(
        body,
        SalesReportLineVerifyData.class
      );
    } catch (JSONException e) {
      throw SalesReportException.of(
        SalesReportException.LINE_ERROR,
        502,
        'LINE verify answered with unreadable JSON.'
      );
    }
  }

  private static String errorDescription(String body) {
    try {
      Object parsed = JSON.deserializeUntyped(body);
      if (parsed instanceof Map<String, Object>) {
        Object value = ((Map<String, Object>) parsed).get('error_description');
        return value == null ? null : String.valueOf(value);
      }
    } catch (JSONException e) {
      return null;
    }
    return null;
  }
}
