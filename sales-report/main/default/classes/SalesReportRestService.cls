/**
 * Shared response handling for the Sales Report Apex REST controllers: JSON bodies, no caching, and the mapping of
 * failures to error responses. Unexpected exceptions are logged in full but answered with a generic message.
 */
public with sharing class SalesReportRestService {
  public static void ok(Object body) {
    write(200, body);
  }

  public static void fail(String source, Exception e) {
    if (e instanceof SalesReportException) {
      SalesReportException known = (SalesReportException) e;
      if (known.code == SalesReportException.TOKEN_EXPIRED) {
        SalesReportLogService.info(
          source,
          known.code + ': ' + known.getMessage()
        );
      } else {
        SalesReportLogService.warn(
          source,
          known.code + ': ' + known.getMessage()
        );
      }
      write(
        known.statusCode,
        new SalesReportErrorData(known.code, known.getMessage())
      );
      return;
    }
    SalesReportLogService.error(source, e);
    write(500, new SalesReportErrorData('INTERNAL', 'Something went wrong.'));
  }

  private static void write(Integer status, Object body) {
    RestResponse res = RestContext.response;
    res.statusCode = status;
    res.addHeader('Content-Type', 'application/json; charset=utf-8');
    res.addHeader('Cache-Control', 'no-store');
    res.responseBody = Blob.valueOf(JSON.serialize(body, true));
  }
}
