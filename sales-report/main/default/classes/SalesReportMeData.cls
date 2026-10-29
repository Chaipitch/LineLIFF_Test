/**
 * Response of GET /salesreport/v1/me.
 */
public with sharing class SalesReportMeData {
  /** True when the LINE user is linked to an active Salesforce User (always false until L3). */
  public Boolean linked = false;
  /** LINE display name from the verified ID token. */
  public String lineDisplayName;
  /** Name of the linked Salesforce User, when linked. */
  public String salesforceUserName;
}
