/**
 * Response of POST /salesreport/v1/link/start.
 */
public with sharing class SalesReportLinkStartData {
  /** One-time link page on the org's own domain, valid for a few minutes. */
  public String linkUrl;
}
