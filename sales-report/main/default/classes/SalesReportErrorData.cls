/**
 * Error response of every Sales Report endpoint: { "error": { "code": "...", "message": "..." } }.
 */
public with sharing class SalesReportErrorData {
  public Detail error;

  public SalesReportErrorData(String code, String message) {
    error = new Detail();
    error.code = code;
    error.message = message;
  }

  public class Detail {
    public String code;
    public String message;
  }
}
