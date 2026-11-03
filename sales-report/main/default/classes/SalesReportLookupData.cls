/**
 * Response of GET /salesreport/v1/opportunities?lookup=<field>&q=… — records for a lookup field of the form (e.g.
 * Main PreSales Engineer → active Users), visible to the rep, by name.
 */
public with sharing class SalesReportLookupData {
  public List<Item> records = new List<Item>();

  public class Item {
    /** Record ID — the form stores this, never the name. */
    public String id;
    public String name;
    /** Extra line under the name (a User's title); may be null. */
    public String detail;
  }
}
