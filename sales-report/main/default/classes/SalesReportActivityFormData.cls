/**
 * Response of GET /salesreport/v1/activity — the Log Activity form for this rep: the field-set fields they can
 * create, with Salesforce's labels (in the rep's language), types, picklist values, defaults and required flags
 * (D-31). The LIFF page builds the form from this; the server checks the same rules again on save.
 */
public with sharing class SalesReportActivityFormData {
  public List<Field> fields = new List<Field>();

  public class Field {
    /** Field API name, the key in the POST body. */
    public String name;
    public String label;
    /** text | textarea | picklist | multipicklist | date | boolean | number | email | phone | url */
    public String type;
    public Boolean required = false;
    public Object defaultValue;
    public Integer maxLength;
    public List<Option> options;
  }

  public class Option {
    public String value;
    public String label;
  }
}
