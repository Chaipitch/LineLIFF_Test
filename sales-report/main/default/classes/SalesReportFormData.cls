/**
 * A LINE form for this rep (Log Activity, Update Opportunity): the field-set fields they can create or edit, with
 * Salesforce's labels (in the rep's language), types, picklist values, defaults or current values, and required flags
 * (D-31). The LIFF page builds the form from this; the server checks the same rules again on save.
 */
public with sharing class SalesReportFormData {
  public List<Field> fields = new List<Field>();

  public class Field {
    /** Field API name, the key in the POST body. */
    public String name;
    public String label;
    /** text | textarea | picklist | multipicklist | date | boolean | number | email | phone | url | lookup */
    public String type;
    public Boolean required = false;
    /** Default for a new record, or the current value when editing. */
    public Object defaultValue;
    public Integer maxLength;
    public List<Option> options;
    /** lookup only: the object searched (e.g. User); the value is a record ID, never a name. */
    public String lookupObject;
    /** lookup only: name of the current record, shown instead of its ID. */
    public String displayValue;
  }

  public class Option {
    public String value;
    public String label;
  }
}
