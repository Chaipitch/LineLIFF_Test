/**
 * Error response of every Sales Report endpoint:
 * { "error": { "code": "...", "message": "...", "fields": {…}, "reference": "..." } }.
 * `fields` (field API name → message) is only present when the form can highlight fields. `reference` is the
 * Salesforce request ID, the same as on the Sales Report Log entry, so support can find it (D-45).
 */
public with sharing class SalesReportErrorData {
  public Detail error;

  public SalesReportErrorData(String code, String message) {
    this(code, message, null);
  }

  public SalesReportErrorData(
    String code,
    String message,
    Map<String, String> fields
  ) {
    error = new Detail();
    error.code = code;
    error.message = message;
    error.fields = fields;
    error.reference = Request.getCurrent().getRequestId();
  }

  public class Detail {
    public String code;
    public String message;
    public Map<String, String> fields;
    public String reference;
  }
}
