/**
 * Expected failure of a Sales Report request. Carries a stable error code (mapped to a Custom Label by the LIFF page)
 * and the HTTP status the REST controller answers with. The message is plain language and never contains tokens,
 * link codes or secrets.
 */
public with sharing class SalesReportException extends Exception {
  public static final String TOKEN_MISSING = 'TOKEN_MISSING';
  public static final String TOKEN_INVALID = 'TOKEN_INVALID';
  public static final String TOKEN_EXPIRED = 'TOKEN_EXPIRED';
  public static final String UNAVAILABLE = 'UNAVAILABLE';
  public static final String CONFIG_MISSING = 'CONFIG_MISSING';
  public static final String LINE_ERROR = 'LINE_ERROR';

  public String code { get; private set; }
  public Integer statusCode { get; private set; }

  public static SalesReportException of(
    String code,
    Integer statusCode,
    String message
  ) {
    SalesReportException e = new SalesReportException(message);
    e.code = code;
    e.statusCode = statusCode;
    return e;
  }
}
