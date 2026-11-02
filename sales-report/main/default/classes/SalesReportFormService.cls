/**
 * Builds a LINE form from a field set and the rep's own view of the object, and checks submitted values against it
 * (D-21, D-31, D-35). Used by Log Activity (Task, new record) and Update Opportunity (existing record).
 *
 * Form fields are the members of the field set (packaging rule P3: no static references to org fields). Labels, types,
 * picklist values, defaults and the rep's layout come from three small User Interface API reads **as the rep**
 * (object-info, layout, picklist-values for the rep's default record type — not record-defaults, which returns every
 * related object, ~4.7 MB). A field is required on the form exactly when Salesforce requires it for this rep: required
 * on their layout, required by the database, or ticked Required in the field set. Validation rules run on save.
 */
public with sharing class SalesReportFormService {
  /** New record (fields the rep can create, Create layout) or existing record (fields the rep can edit, Edit layout). */
  public enum Purpose {
    NEW_RECORD,
    EDIT_RECORD
  }

  @TestVisible
  static final String MASTER_RECORD_TYPE_ID = '012000000000000AAA';
  private static final String SOURCE = 'SalesReportFormService';
  /** UI API dataType → form input type. Other types (lookups, date/time, …) are left off the form. */
  private static final Map<String, String> INPUT_TYPES = new Map<String, String>{
    'String' => 'text',
    'ComboBox' => 'text',
    'TextArea' => 'textarea',
    'Picklist' => 'picklist',
    'MultiPicklist' => 'multipicklist',
    'Date' => 'date',
    'Boolean' => 'boolean',
    'Double' => 'number',
    'Int' => 'number',
    'Currency' => 'number',
    'Percent' => 'number',
    'Email' => 'email',
    'Phone' => 'phone',
    'Url' => 'url'
  };
  private static final Set<String> TEXT_TYPES = new Set<String>{
    'text',
    'textarea',
    'email',
    'phone',
    'url'
  };
  private static final Pattern ISO_DATE = Pattern.compile(
    '\\d{4}-\\d{2}-\\d{2}'
  );

  public final String objectName;
  public final String fieldSetName;
  public final Purpose purpose;
  public final SalesReportFormData form = new SalesReportFormData();
  public final Map<String, SalesReportFormData.Field> byName = new Map<String, SalesReportFormData.Field>();
  /** UI API field infos of the object (label, dataType, required, createable, updateable, length). */
  public final Map<String, Object> fieldInfos;
  /** Picklist defaults of the rep's record type (e.g. Status = Open, Priority = Normal). */
  public final Map<String, Object> defaults = new Map<String, Object>();
  public final Set<String> layoutRequired = new Set<String>();
  public final String objectLabel;

  public SalesReportFormService(
    SalesReportOrgApiCalloutService api,
    Schema.SObjectType objectType,
    String fieldSetName,
    Purpose purpose
  ) {
    Schema.DescribeSObjectResult describe = objectType.getDescribe();
    this.objectName = describe.getName();
    this.fieldSetName = fieldSetName;
    this.purpose = purpose;
    Schema.FieldSet fieldSet = describe.fieldSets.getMap().get(fieldSetName);
    if (fieldSet == null) {
      throw SalesReportException.of(
        SalesReportException.CONFIG_MISSING,
        503,
        'Field set ' + fieldSetName + ' on ' + objectName + ' is missing.'
      );
    }

    Map<String, Object> objectInfo = api.uiApi('object-info/' + objectName);
    objectLabel = (String) objectInfo.get('label');
    fieldInfos = (Map<String, Object>) objectInfo.get('fields');
    String recordTypeId = (String) objectInfo.get('defaultRecordTypeId');
    if (String.isBlank(recordTypeId)) {
      recordTypeId = MASTER_RECORD_TYPE_ID;
    }
    readLayout(
      api.uiApi(
        'layout/' +
          objectName +
          '?mode=' +
          (purpose == SalesReportFormService.Purpose.NEW_RECORD
            ? 'Create'
            : 'Edit') +
          '&layoutType=Full&recordTypeId=' +
          recordTypeId
      )
    );
    Map<String, Object> picklists = (Map<String, Object>) api.uiApi(
        'object-info/' + objectName + '/picklist-values/' + recordTypeId
      )
      .get('picklistFieldValues');
    readPicklistDefaults(picklists);

    for (Schema.FieldSetMember member : fieldSet.getFields()) {
      SalesReportFormData.Field field = formField(member);
      if (field != null) {
        form.fields.add(field);
        byName.put(field.name, field);
      }
    }
    addPicklistValues(picklists);
  }

  /**
   * Submitted values → field values in Salesforce types. A field that is not on the form stops the request; invalid
   * or missing required values are collected in errors (field name → message). When editing, a field sent empty is
   * returned as null so the value is cleared.
   */
  public Map<String, Object> values(
    Map<String, Object> submitted,
    Map<String, String> errors
  ) {
    for (String name : submitted.keySet()) {
      if (!byName.containsKey(name)) {
        throw SalesReportException.of(
          SalesReportException.INVALID_INPUT,
          400,
          'Field ' + name + ' cannot be set from LINE.'
        );
      }
    }
    Map<String, Object> result = new Map<String, Object>();
    for (SalesReportFormData.Field field : form.fields) {
      Object value = coerced(field, submitted.get(field.name), errors);
      if (value != null) {
        result.put(field.name, value);
      } else if (errors.containsKey(field.name)) {
        continue;
      } else if (field.required) {
        errors.put(field.name, 'Required.');
      } else if (
        purpose == SalesReportFormService.Purpose.EDIT_RECORD &&
        submitted.containsKey(field.name)
      ) {
        result.put(field.name, null);
      }
    }
    return result;
  }

  /** Keeps only the listed picklist values of one form field (e.g. open Opportunity stages). */
  public void restrictOptions(String fieldName, Set<String> allowedValues) {
    SalesReportFormData.Field field = byName.get(fieldName);
    if (field == null || field.options == null) {
      return;
    }
    List<SalesReportFormData.Option> kept = new List<SalesReportFormData.Option>();
    for (SalesReportFormData.Option option : field.options) {
      if (allowedValues.contains(option.value)) {
        kept.add(option);
      }
    }
    field.options = kept;
  }

  /** Adds a picklist value that Salesforce no longer offers (e.g. a record's current, now inactive, stage). */
  public void keepOption(String fieldName, String value) {
    SalesReportFormData.Field field = byName.get(fieldName);
    if (field == null || field.options == null || value == null) {
      return;
    }
    for (SalesReportFormData.Option option : field.options) {
      if (option.value == value) {
        return;
      }
    }
    SalesReportFormData.Option kept = new SalesReportFormData.Option();
    kept.value = value;
    kept.label = value;
    field.options.add(0, kept);
  }

  /** The rep's value in the field's type; null when empty. Invalid values add an error and return null. */
  @TestVisible
  static Object coerced(
    SalesReportFormData.Field field,
    Object raw,
    Map<String, String> errors
  ) {
    if (
      raw == null || (raw instanceof String && String.isBlank((String) raw))
    ) {
      return null;
    }
    switch on field.type {
      when 'boolean' {
        if (raw instanceof Boolean) {
          return raw;
        }
      }
      when 'number' {
        try {
          return Decimal.valueOf(String.valueOf(raw));
        } catch (TypeException e) {
          errors.put(field.name, 'Enter a number.');
          return null;
        }
      }
      when 'date' {
        try {
          if (
            raw instanceof String && ISO_DATE.matcher((String) raw).matches()
          ) {
            return Date.valueOf((String) raw);
          }
        } catch (TypeException e) {
          SalesReportLogService.info(SOURCE, 'Unreadable date: ' + raw);
        }
        errors.put(field.name, 'Enter a valid date.');
        return null;
      }
      when 'picklist' {
        if (raw instanceof String && allowed(field, (String) raw)) {
          return raw;
        }
      }
      when 'multipicklist' {
        List<Object> items = raw instanceof List<Object>
          ? (List<Object>) raw
          : new List<Object>{ raw };
        List<String> chosen = new List<String>();
        for (Object item : items) {
          if (!(item instanceof String) || !allowed(field, (String) item)) {
            errors.put(field.name, 'Choose from the list.');
            return null;
          }
          chosen.add((String) item);
        }
        return chosen.isEmpty() ? null : String.join(chosen, ';');
      }
      when else {
        if (raw instanceof String) {
          String text = (String) raw;
          if (field.maxLength != null && text.length() > field.maxLength) {
            errors.put(
              field.name,
              'Too long (max ' + field.maxLength + ' characters).'
            );
            return null;
          }
          return text;
        }
      }
    }
    errors.put(
      field.name,
      field.type == 'picklist' ? 'Choose from the list.' : 'Invalid value.'
    );
    return null;
  }

  /** Request body → JSON object; INVALID_INPUT otherwise. */
  public static Map<String, Object> parseBody(String body) {
    Object value;
    try {
      value = JSON.deserializeUntyped(body == null ? '' : body);
    } catch (JSONException e) {
      value = null;
    }
    if (value instanceof Map<String, Object>) {
      return (Map<String, Object>) value;
    }
    throw SalesReportException.of(
      SalesReportException.INVALID_INPUT,
      400,
      'The request body must be a JSON object.'
    );
  }

  /** The body's "values" object (field name → value); empty when missing. */
  public static Map<String, Object> valuesOf(Object raw) {
    if (raw == null) {
      return new Map<String, Object>();
    }
    if (raw instanceof Map<String, Object>) {
      return (Map<String, Object>) raw;
    }
    throw SalesReportException.of(
      SalesReportException.INVALID_INPUT,
      400,
      '"values" must be an object of field name to value.'
    );
  }

  /** A string property of the body, or null. */
  public static String stringOf(Map<String, Object> input, String key) {
    Object value = input.get(key);
    return value instanceof String ? (String) value : null;
  }

  private static Boolean allowed(
    SalesReportFormData.Field field,
    String value
  ) {
    if (field.options == null) {
      return false;
    }
    for (SalesReportFormData.Option option : field.options) {
      if (option.value == value) {
        return true;
      }
    }
    return false;
  }

  private void readPicklistDefaults(Map<String, Object> picklists) {
    for (String name : picklists.keySet()) {
      Map<String, Object> defaultValue = (Map<String, Object>) ((Map<String, Object>) picklists.get(
          name
        ))
        .get('defaultValue');
      if (defaultValue != null && defaultValue.get('value') != null) {
        defaults.put(name, defaultValue.get('value'));
      }
    }
  }

  private void readLayout(Map<String, Object> layout) {
    if (layout == null) {
      return;
    }
    for (Object section : (List<Object>) layout.get('sections')) {
      for (
        Object row : (List<Object>) ((Map<String, Object>) section)
          .get('layoutRows')
      ) {
        for (
          Object item : (List<Object>) ((Map<String, Object>) row)
            .get('layoutItems')
        ) {
          Map<String, Object> layoutItem = (Map<String, Object>) item;
          if (layoutItem.get('required') != true) {
            continue;
          }
          for (
            Object component : (List<Object>) layoutItem.get('layoutComponents')
          ) {
            Object apiName = ((Map<String, Object>) component).get('apiName');
            if (apiName != null) {
              layoutRequired.add((String) apiName);
            }
          }
        }
      }
    }
  }

  /** Null when the rep can't create/edit the field or the form can't show its type. */
  private SalesReportFormData.Field formField(Schema.FieldSetMember member) {
    String name = member.getFieldPath();
    Map<String, Object> info = (Map<String, Object>) fieldInfos.get(name);
    String access = purpose == SalesReportFormService.Purpose.NEW_RECORD
      ? 'createable'
      : 'updateable';
    if (name.contains('.') || info == null || info.get(access) != true) {
      return null;
    }
    String inputType = INPUT_TYPES.get((String) info.get('dataType'));
    if (inputType == null) {
      SalesReportLogService.warn(
        SOURCE,
        'Field set ' +
          fieldSetName +
          ': ' +
          name +
          ' (' +
          info.get('dataType') +
          ') is not supported on the form and was left out.'
      );
      return null;
    }
    SalesReportFormData.Field field = new SalesReportFormData.Field();
    field.name = name;
    field.label = (String) info.get('label');
    field.type = inputType;
    field.required =
      inputType != 'boolean' &&
      (member.getRequired() ||
      info.get('required') == true ||
      layoutRequired.contains(name));
    field.defaultValue = defaults.get(name);
    if (TEXT_TYPES.contains(inputType) && info.get('length') != null) {
      Integer length = Integer.valueOf(info.get('length'));
      field.maxLength = length > 0 ? length : null;
    }
    return field;
  }

  private void addPicklistValues(Map<String, Object> picklists) {
    for (SalesReportFormData.Field field : form.fields) {
      if (field.type != 'picklist' && field.type != 'multipicklist') {
        continue;
      }
      field.options = new List<SalesReportFormData.Option>();
      Map<String, Object> picklist = (Map<String, Object>) picklists.get(
        field.name
      );
      if (picklist == null) {
        continue;
      }
      for (Object entry : (List<Object>) picklist.get('values')) {
        Map<String, Object> value = (Map<String, Object>) entry;
        SalesReportFormData.Option option = new SalesReportFormData.Option();
        option.value = (String) value.get('value');
        option.label = (String) value.get('label');
        field.options.add(option);
      }
    }
  }
}
