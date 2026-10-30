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
  public static final String LINK_CODE_INVALID = 'LINK_CODE_INVALID';
  public static final String NOT_AUTHORIZED = 'NOT_AUTHORIZED';
  public static final String SESSION_ERROR = 'SESSION_ERROR';
  public static final String NOT_LINKED = 'NOT_LINKED';
  public static final String QUERY_TOO_SHORT = 'QUERY_TOO_SHORT';
  public static final String INVALID_INPUT = 'INVALID_INPUT';
  public static final String SAVE_FAILED = 'SAVE_FAILED';
  public static final String RATE_LIMITED = 'RATE_LIMITED';

  public String code { get; private set; }
  public Integer statusCode { get; private set; }
  /** Field API name → plain-language message, for errors the form shows next to a field; null when none. */
  public Map<String, String> fieldErrors { get; private set; }

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

  public static SalesReportException withFields(
    String code,
    Integer statusCode,
    String message,
    Map<String, String> fieldErrors
  ) {
    SalesReportException e = of(code, statusCode, message);
    e.fieldErrors = fieldErrors == null || fieldErrors.isEmpty()
      ? null
      : fieldErrors;
    return e;
  }
}
