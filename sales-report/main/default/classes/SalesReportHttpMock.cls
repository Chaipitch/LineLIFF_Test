/**
 * Callout mock for Sales Report tests: answers every request with one status and body (or throws a CalloutException)
 * and remembers the last request so tests can assert what was sent.
 */
@IsTest
public with sharing class SalesReportHttpMock implements HttpCalloutMock {
  private final Integer status;
  private final String body;
  private final Boolean fail;
  public HttpRequest lastRequest;

  public SalesReportHttpMock(Integer status, String body) {
    this.status = status;
    this.body = body;
    this.fail = false;
  }

  private SalesReportHttpMock() {
    this.status = null;
    this.body = null;
    this.fail = true;
  }

  public static SalesReportHttpMock unreachable() {
    return new SalesReportHttpMock();
  }

  public HttpResponse respond(HttpRequest req) {
    lastRequest = req;
    if (fail) {
      throw new CalloutException('Read timed out');
    }
    HttpResponse res = new HttpResponse();
    res.setStatusCode(status);
    res.setHeader('Content-Type', 'application/json');
    res.setBody(body);
    return res;
  }
}
