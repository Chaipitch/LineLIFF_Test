/**
 * Response of POST /salesreport/v1/activity/files — one file attached to the rep's Task.
 */
public with sharing class SalesReportActivityFileData {
  /** ContentVersion ID. */
  public String id;
  public String name;
  /** Bytes. */
  public Integer size;
}
