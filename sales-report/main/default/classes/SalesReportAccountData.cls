/**
 * Response of GET /salesreport/v1/accounts?q=… — Accounts the rep can see, best matches first.
 */
public with sharing class SalesReportAccountData {
  public List<Item> accounts = new List<Item>();

  public class Item {
    /** Account ID — the form stores this, never the name. */
    public String id;
    public String name;
    /** First other search field with a value (e.g. a local-language name), shown under the name; may be null. */
    public String detail;
  }
}
