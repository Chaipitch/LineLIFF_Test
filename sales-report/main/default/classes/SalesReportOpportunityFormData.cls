/**
 * Response of GET /salesreport/v1/opportunities?id=… (the update form, fields filled with the current values) and of
 * POST /salesreport/v1/opportunities (the updated Opportunity; fields omitted).
 */
public with sharing class SalesReportOpportunityFormData {
  public String id;
  public String name;
  public String accountId;
  public List<SalesReportFormData.Field> fields;
}
