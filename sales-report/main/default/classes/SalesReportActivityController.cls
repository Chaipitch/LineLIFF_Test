/**
 * /services/apexrest/salesreport/v1/activity — Log Activity for the linked rep, run as the rep (Option B, D-11).
 * GET: the form definition (fields, labels, required flags; D-31). POST { accountId, values }: creates the Task.
 * Exposed to the Site guest user (`global` is required by @RestResource).
 */
@RestResource(urlMapping='/salesreport/v1/activity')
global with sharing class SalesReportActivityController {
  @TestVisible
  static final String SOURCE_FORM = 'SalesReportActivityController.form';
  @TestVisible
  static final String SOURCE_CREATE = 'SalesReportActivityController.create';

  @HttpGet
  global static void form() {
    try {
      SalesReportOrgApiCalloutService api = new SalesReportIdentityService()
        .repSession(RestContext.request);
      SalesReportRestService.ok(new SalesReportActivityService().form(api));
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE_FORM, e);
    } finally {
      SalesReportLogService.flush();
    }
  }

  @HttpPost
  global static void create() {
    try {
      SalesReportOrgApiCalloutService api = new SalesReportIdentityService()
        .repSession(RestContext.request);
      Blob body = RestContext.request.requestBody;
      SalesReportRestService.ok(
        new SalesReportActivityService()
          .create(api, body == null ? null : body.toString())
      );
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE_CREATE, e);
    } finally {
      SalesReportLogService.flush();
    }
  }
}
