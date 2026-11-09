/**
 * Response of GET /salesreport/v1/activity?accountId=… — what a Log Activity can be linked to on that Account, as the
 * rep sees it: its Opportunities (for "Related To", open first) and its Contacts (for "Name") (D-54).
 */
public with sharing class SalesReportActivityRelatedData {
  public List<Item> opportunities = new List<Item>();
  public List<Item> contacts = new List<Item>();

  public class Item {
    /** Record ID — the form sends this back, never the name. */
    public String id;
    public String name;
    /** Opportunity stage label, or the Contact's title; may be null. */
    public String detail;
  }
}
