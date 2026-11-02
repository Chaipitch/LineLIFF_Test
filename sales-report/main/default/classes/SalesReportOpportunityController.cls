/**
 * /services/apexrest/salesreport/v1/opportunities — Update Opportunity for the linked rep, run as the rep (Option B).
 * GET ?accountId=…: the Account's open Opportunities. GET ?id=…: the update form with current values.
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
      checkEnabled();
      SalesReportOrgApiCalloutService api = new SalesReportIdentityService()
        .repSession(RestContext.request);
      Map<String, String> params = RestContext.request.params;
      SalesReportOpportunityService service = new SalesReportOpportunityService();
      SalesReportRestService.ok(
        params.containsKey('id')
          ? (Object) service.form(api, params.get('id'))
          : (Object) service.listOpen(api, params.get('accountId'))
      );
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE_GET, e);
    } finally {
      SalesReportRestService.finish();
    }
  }

  @HttpPost
  global static void save() {
    try {
      checkEnabled();
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

  /** Refused before any callout while setting Update Opportunity Enabled is unticked. */
  private static void checkEnabled() {
    if (!SalesReportSettingsService.opportunityFormEnabled()) {
      throw SalesReportException.of(
        SalesReportException.NOT_AUTHORIZED,
        403,
        'Update Opportunity is switched off in Sales Report Settings.'
      );
    }
  }
}
