/**
 * POST /services/apexrest/salesreport/v1/activity/files?taskId=…&name=… — attach one file (raw bytes in the body)
 * to a Task the linked rep just logged, uploaded as the rep (Option B, D-34). Exposed to the Site guest user
 * (`global` is required by @RestResource).
 */
@RestResource(urlMapping='/salesreport/v1/activity/files')
global with sharing class SalesReportActivityFileController {
  @TestVisible
  static final String SOURCE = 'SalesReportActivityFileController.attach';

  @HttpPost
  global static void attach() {
    try {
      SalesReportOrgApiCalloutService api = new SalesReportIdentityService()
        .repSession(RestContext.request);
      Map<String, String> params = RestContext.request.params;
      SalesReportRestService.ok(
        new SalesReportActivityFileService()
          .attach(
            api,
            params.get('taskId'),
            params.get('name'),
            RestContext.request.requestBody
          )
      );
    } catch (Exception e) {
      SalesReportRestService.fail(SOURCE, e);
    } finally {
      SalesReportLogService.flush();
    }
  }
}
