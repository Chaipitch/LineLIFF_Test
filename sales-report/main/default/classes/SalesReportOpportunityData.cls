/**
 * Response of GET /salesreport/v1/opportunities?accountId=… — the Account's open Opportunities the rep can see.
 */
public with sharing class SalesReportOpportunityData {
  public List<Item> opportunities = new List<Item>();

  public class Item {
    public String id;
    public String name;
    /** Stage label in the rep's language. */
    public String stage;
    /** yyyy-mm-dd */
    public String closeDate;
    public String ownerName;
  }
}
