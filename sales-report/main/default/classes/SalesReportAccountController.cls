/**
 * GET /services/apexrest/salesreport/v1/accounts?q=… — Account auto-complete for the linked rep, run as the rep
 * (Option B). Exposed to the Site guest user (`global` is required by @RestResource).
 */
@RestResource(urlMapping='/salesreport/v1/accounts')
global with sharing class SalesReportAccountController {
  @TestVisible
  static final String SOURCE = 'SalesReportAccountController.search';

  @HttpGet
  global static void search() {
    try {
      SalesReportOrgApiCalloutService api = new SalesReportIdentityService()
        .repSession(RestContext.request);
      SalesReportRestService.ok(
        new SalesReportAccountService()
          .search(api, RestContext.request.params.get('q'))
      );
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE, e);
    } finally {
      SalesReportRestService.finish();
    }
  }
}
