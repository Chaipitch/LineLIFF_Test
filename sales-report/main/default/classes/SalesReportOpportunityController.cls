/**
 * /services/apexrest/salesreport/v1/opportunities — Update Opportunity for the linked rep, run as the rep (Option B).
 * GET ?accountId=…: the Account's Opportunities (open first, then closed). GET ?id=…: the update form with current values.
 * GET ?lookup=<field>&q=…: search for a lookup field of the form (e.g. Main PreSales Engineer → active Users).
 * POST { id, accountId, values }: update the Opportunity. One class (one guest-profile grant) for the whole form.
 * Exposed to the Site guest user (`global` is required by @RestResource).
 */
@RestResource(urlMapping='/salesreport/v1/opportunities')
global with sharing class SalesReportOpportunityController {
  @TestVisible
  static final String SOURCE_GET = 'SalesReportOpportunityController.getOpportunities';
  @TestVisible
  static final String SOURCE_SAVE = 'SalesReportOpportunityController.save';

  @HttpGet
  global static void getOpportunities() {
    try {
      SalesReportOrgApiCalloutService api = new SalesReportIdentityService()
        .repSession(RestContext.request);
      Map<String, String> params = RestContext.request.params;
      SalesReportOpportunityService service = new SalesReportOpportunityService();
      Object result;
      if (params.containsKey('lookup')) {
        result = service.searchLookup(
          api,
          params.get('lookup'),
          params.get('q')
        );
      } else if (params.containsKey('id')) {
        result = service.form(api, params.get('id'));
      } else {
        result = service.listForAccount(api, params.get('accountId'));
      }
      SalesReportRestService.ok(result);
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE_GET, e);
    } finally {
      SalesReportRestService.finish();
    }
  }

  @HttpPost
  global static void save() {
    try {
      SalesReportOrgApiCalloutService api = new SalesReportIdentityService()
        .repSession(RestContext.request);
      Blob body = RestContext.request.requestBody;
      SalesReportRestService.ok(
        new SalesReportOpportunityService()
          .save(api, body == null ? null : body.toString())
      );
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE_SAVE, e);
    } finally {
      SalesReportRestService.finish();
    }
  }
}
