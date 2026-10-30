/**
 * POST /services/apexrest/salesreport/v1/link/start — first step of the one-time login (flow B): verifies the LINE ID
 * token and returns a single-use link page URL. Exposed to the Site guest user (`global` is required by @RestResource).
 */
@RestResource(urlMapping='/salesreport/v1/link/start')
global with sharing class SalesReportLinkController {
  @TestVisible
  static final String SOURCE = 'SalesReportLinkController.start';

  @HttpPost
  global static void start() {
    try {
      SalesReportLineVerifyData identity = new SalesReportIdentityService()
        .identify(RestContext.request);
      String code = new SalesReportLinkService().createCode(identity);
      SalesReportLinkStartData body = new SalesReportLinkStartData();
      body.linkUrl = SalesReportLinkService.linkPageUrl(code);
      SalesReportLogService.info(SOURCE, 'Link code created.');
      SalesReportRestService.ok(body);
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE, e);
    } finally {
      SalesReportRestService.finish();
    }
  }
}
