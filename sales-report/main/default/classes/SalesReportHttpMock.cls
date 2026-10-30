/**
 * Callout mock for Sales Report tests. Answers with one default status and body (or throws a CalloutException), or
 * per endpoint when routes are added with route(); remembers the requests so tests can assert what was sent.
 */
@IsTest
public with sharing class SalesReportHttpMock implements HttpCalloutMock {
  private final Integer status;
  private final String body;
  private final Boolean fail;
  private final Map<String, HttpResponse> routes = new Map<String, HttpResponse>();
  public HttpRequest lastRequest;
  public List<HttpRequest> requests = new List<HttpRequest>();

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

  /** Requests whose endpoint contains endpointPart get this answer instead of the default. */
  public SalesReportHttpMock route(
    String endpointPart,
    Integer routeStatus,
    String routeBody
  ) {
    routes.put(endpointPart, response(routeStatus, routeBody));
    return this;
  }

  public HttpResponse respond(HttpRequest req) {
    lastRequest = req;
    requests.add(req);
    String match;
    for (String endpointPart : routes.keySet()) {
      if (
        req.getEndpoint().contains(endpointPart) &&
        (match == null ||
        endpointPart.length() > match.length())
      ) {
        match = endpointPart;
      }
    }
    if (match != null) {
      return routes.get(match);
    }
    if (fail) {
      throw new CalloutException('Read timed out');
    }
    return response(status, body);
  }

  private static HttpResponse response(Integer status, String body) {
    HttpResponse res = new HttpResponse();
    res.setStatusCode(status);
    res.setHeader('Content-Type', 'application/json');
    res.setBody(body);
    return res;
  }
}
