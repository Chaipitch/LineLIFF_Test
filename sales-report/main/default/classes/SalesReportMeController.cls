/**
 * GET /services/apexrest/salesreport/v1/me — first call of every LIFF page load: verifies the LINE ID token and
 * tells the page who the rep is. When the LINE user is linked, the Salesforce name is read through a session of the
 * rep (Option B), which also proves that the JWT exchange works for this user. Exposed to the Site guest user
 * (`global` is required by @RestResource). Order: LINE callout, link lookup (may unlink: DML), then org callouts only
 * when a link was found, then the log flush.
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
      SalesReport_Line_Link__c link = new SalesReportLinkService()
        .findActiveLink(identity.sub);
      if (link != null) {
        String accessToken = new SalesReportSessionCalloutService()
          .accessTokenFor(link.User__r.Username);
        Map<String, Object> userInfo = new SalesReportOrgApiCalloutService(
            accessToken
          )
          .userInfo();
        body.linked = true;
        body.salesforceUserName = (String) userInfo.get('name');
      }
      SalesReportRestService.ok(body);
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE, e);
    } finally {
      SalesReportLogService.flush();
    }
  }
}
