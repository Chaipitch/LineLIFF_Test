/**
 * GET /services/apexrest/salesreport/v1/me — first call of every LIFF page load: verifies the LINE ID token and
 * tells the page who the rep is. Exposed to the Site guest user (`global` is required by @RestResource).
 */
@RestResource(urlMapping='/salesreport/v1/me')
global with sharing class SalesReportMeController {
  @TestVisible
  static final String SOURCE = 'SalesReportMeController.getMe';

  @HttpGet
  global static void getMe() {
    try {
      SalesReportLineVerifyData identity = new SalesReportIdentityService()
        .identify(RestContext.request);
      SalesReportMeData body = new SalesReportMeData();
      body.lineDisplayName = identity.name;
      SalesReportRestService.ok(body);
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE, e);
    } finally {
      SalesReportLogService.flush();
    }
  }
}
