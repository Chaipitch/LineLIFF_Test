/**
 * Response of GET /salesreport/v1/connection.
 */
public with sharing class SalesReportConnectionData {
  /** True when the LINE user is linked to an active Salesforce User. */
  public Boolean linked = false;
  /** LINE display name from the verified ID token. */
  public String lineDisplayName;
  /** Name of the linked Salesforce User, read through a session of that user (Option B). */
  public String salesforceUserName;
}
