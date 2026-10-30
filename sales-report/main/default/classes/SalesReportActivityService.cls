/**
 * Log Activity (L5a): the form definition and the Task create, both **as the rep** (Option B).
 *
 * Form fields are the members of field set SalesReport_Activity_Form on Task (D-21, packaging rule P3). Labels, types,
 * picklist values and defaults and the rep's own layout come from the User Interface API in the rep's session
 * (object-info, layout, picklist-values for the rep's default record type), so a field is required on
 * the form exactly when Salesforce requires it for this rep: required on their layout, required by the database, or
 * ticked Required in the field set (D-31). Validation rules run on save; their messages come back as SAVE_FAILED.
 *
 * The Task is linked to the Account only (D-33). Subject is built from Type + Account name, Status follows the date
 * (D-32), other layout-required fields take the layout's defaults, OwnerId defaults to the rep.
 */
public with sharing class SalesReportActivityService {
  public static final String FORM_FIELD_SET = 'SalesReport_Activity_Form';
  @TestVisible
  static final String MASTER_RECORD_TYPE_ID = '012000000000000AAA';
  private static final String TASK_OBJECT = 'Task';
  @TestVisible
  static final String SOURCE = 'SalesReportActivityService';
  /** Filled by the server (or by Salesforce), never required from the rep. */
  private static final Set<String> SERVER_FIELDS = new Set<String>{
    'Subject',
    'Status',
    'OwnerId',
    'WhatId'
  };
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
  private static final Pattern ACCOUNT_ID = Pattern.compile(
    '001[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?'
  );
  private static final Pattern ISO_DATE = Pattern.compile(
    '\\d{4}-\\d{2}-\\d{2}'
  );

  public SalesReportActivityFormData form(SalesReportOrgApiCalloutService api) {
    return new FormContext(api).form;
  }

  public SalesReportActivityData create(
    SalesReportOrgApiCalloutService api,
    String body
  ) {
    Map<String, Object> input = parsed(body);
    Map<String, Object> values = valuesOf(input.get('values'));
    String accountId = input.get('accountId') instanceof String
      ? (String) input.get('accountId')
      : null;

    FormContext context = new FormContext(api);
    for (String name : values.keySet()) {
      if (!context.byName.containsKey(name)) {
        throw SalesReportException.of(
          SalesReportException.INVALID_INPUT,
          400,
          'Field ' + name + ' cannot be set from LINE.'
        );
      }
    }

    Map<String, String> errors = new Map<String, String>();
    Map<String, Object> task = new Map<String, Object>();
    for (SalesReportActivityFormData.Field field : context.form.fields) {
      Object value = coerced(field, values.get(field.name), errors);
      if (value != null) {
        task.put(field.name, value);
      } else if (field.required && !errors.containsKey(field.name)) {
        errors.put(field.name, 'Required.');
      }
    }
    if (accountId == null || !ACCOUNT_ID.matcher(accountId).matches()) {
      errors.put('accountId', 'Choose an Account.');
    }
    if (!errors.isEmpty()) {
      throw SalesReportException.withFields(
        SalesReportException.INVALID_INPUT,
        400,
        'Please check the highlighted fields.',
        errors
      );
    }

    String accountName = visibleAccountName(api, accountId);
    task.put('WhatId', accountId);
    if (!task.containsKey('Subject')) {
      task.put('Subject', context.subject(task, accountName));
    }
    if (!context.byName.containsKey('Status')) {
      task.put(
        'Status',
        context.status((Date) task.get('ActivityDate'), api.repToday())
      );
    }
    context.fillServerRequired(task);

    SalesReportActivityData result = new SalesReportActivityData();
    result.id = api.create(TASK_OBJECT, task);
    result.subject = (String) task.get('Subject');
    result.status = (String) task.get('Status');
    return result;
  }

  private static Map<String, Object> parsed(String body) {
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

  private static Map<String, Object> valuesOf(Object raw) {
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

  /** The Account through the rep's session: proves the rep can see it and gives the name for the Subject. */
  private static String visibleAccountName(
    SalesReportOrgApiCalloutService api,
    String accountId
  ) {
    // accountId matched ACCOUNT_ID above, so it is safe to inline.
    List<Object> records = api.query(
      'SELECT Id, Name FROM Account WHERE Id = \'' + accountId + '\' LIMIT 1'
    );
    if (records.isEmpty()) {
      throw SalesReportException.withFields(
        SalesReportException.INVALID_INPUT,
        400,
        'This Account was not found or you cannot see it.',
        new Map<String, String>{ 'accountId' => 'Account not found.' }
      );
    }
    return (String) ((Map<String, Object>) records[0]).get('Name');
  }

  /** The rep's value in the field's type; null when empty. Invalid values add an error and return null. */
  @TestVisible
  static Object coerced(
    SalesReportActivityFormData.Field field,
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

  private static Boolean allowed(
    SalesReportActivityFormData.Field field,
    String value
  ) {
    if (field.options == null) {
      return false;
    }
    for (SalesReportActivityFormData.Option option : field.options) {
      if (option.value == value) {
        return true;
      }
    }
    return false;
  }

  /** Everything Salesforce says about creating a Task for this rep, read once per request. */
  private class FormContext {
    final SalesReportActivityFormData form = new SalesReportActivityFormData();
    final Map<String, SalesReportActivityFormData.Field> byName = new Map<String, SalesReportActivityFormData.Field>();
    final Map<String, Object> fieldInfos;
    final Map<String, Object> defaults = new Map<String, Object>();
    final Set<String> layoutRequired = new Set<String>();
    final String objectLabel;

    FormContext(SalesReportOrgApiCalloutService api) {
      Schema.FieldSet fieldSet = Schema.SObjectType.Task.fieldSets.getMap()
        .get(FORM_FIELD_SET);
      if (fieldSet == null) {
        throw SalesReportException.of(
          SalesReportException.CONFIG_MISSING,
          503,
          'Field set ' + FORM_FIELD_SET + ' on Task is missing.'
        );
      }

      // Three small UI API reads as the rep (record-defaults would also return every related object, ~4.7 MB).
      Map<String, Object> objectInfo = api.uiApi('object-info/' + TASK_OBJECT);
      objectLabel = (String) objectInfo.get('label');
      fieldInfos = (Map<String, Object>) objectInfo.get('fields');
      String recordTypeId = (String) objectInfo.get('defaultRecordTypeId');
      if (String.isBlank(recordTypeId)) {
        recordTypeId = MASTER_RECORD_TYPE_ID;
      }
      readLayout(
        api.uiApi(
          'layout/' +
            TASK_OBJECT +
            '?mode=Create&layoutType=Full&recordTypeId=' +
            recordTypeId
        )
      );
      Map<String, Object> picklists = (Map<String, Object>) api.uiApi(
          'object-info/' + TASK_OBJECT + '/picklist-values/' + recordTypeId
        )
        .get('picklistFieldValues');
      readPicklistDefaults(picklists);

      for (Schema.FieldSetMember member : fieldSet.getFields()) {
        SalesReportActivityFormData.Field field = formField(member);
        if (field != null) {
          form.fields.add(field);
          byName.put(field.name, field);
        }
      }
      addPicklistValues(picklists);
    }

    /** Picklist defaults of the rep's record type (e.g. Status = Open, Priority = Normal). */
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
              Object component : (List<Object>) layoutItem.get(
                'layoutComponents'
              )
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

    /** Null when the rep can't create the field or the form can't show its type. */
    private SalesReportActivityFormData.Field formField(
      Schema.FieldSetMember member
    ) {
      String name = member.getFieldPath();
      Map<String, Object> info = (Map<String, Object>) fieldInfos.get(name);
      if (
        name.contains('.') ||
        info == null ||
        info.get('createable') != true
      ) {
        return null;
      }
      String inputType = INPUT_TYPES.get((String) info.get('dataType'));
      if (inputType == null) {
        SalesReportLogService.warn(
          SOURCE,
          'Field set ' +
            FORM_FIELD_SET +
            ': ' +
            name +
            ' (' +
            info.get('dataType') +
            ') is not supported on the form and was left out.'
        );
        return null;
      }
      SalesReportActivityFormData.Field field = new SalesReportActivityFormData.Field();
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
      for (SalesReportActivityFormData.Field field : form.fields) {
        if (field.type != 'picklist' && field.type != 'multipicklist') {
          continue;
        }
        field.options = new List<SalesReportActivityFormData.Option>();
        Map<String, Object> picklist = (Map<String, Object>) picklists.get(
          field.name
        );
        if (picklist == null) {
          continue;
        }
        for (Object entry : (List<Object>) picklist.get('values')) {
          Map<String, Object> value = (Map<String, Object>) entry;
          SalesReportActivityFormData.Option option = new SalesReportActivityFormData.Option();
          option.value = (String) value.get('value');
          option.label = (String) value.get('label');
          field.options.add(option);
        }
      }
    }

    /** "<Type label> – <Account name>", or "<Task label> – <Account name>" without a Type. */
    String subject(Map<String, Object> task, String accountName) {
      String prefix = objectLabel;
      SalesReportActivityFormData.Field typeField = byName.get('Type');
      if (typeField != null && task.get('Type') != null) {
        prefix = (String) task.get('Type');
        for (SalesReportActivityFormData.Option option : typeField.options) {
          if (option.value == task.get('Type')) {
            prefix = option.label;
          }
        }
      }
      Integer maxLength = 255;
      Map<String, Object> info = (Map<String, Object>) fieldInfos.get(
        'Subject'
      );
      if (info != null && info.get('length') != null) {
        maxLength = Integer.valueOf(info.get('length'));
      }
      return String.format(
          System.Label.SalesReport_Activity_Subject,
          new List<String>{ prefix, accountName }
        )
        .left(maxLength);
    }

    /** Today or earlier (or no date) → the first closed Task status; future → the layout's default (D-32). */
    String status(Date activityDate, Date repToday) {
      List<TaskStatus> statuses = [
        SELECT ApiName, IsClosed, IsDefault
        FROM TaskStatus
        WITH SYSTEM_MODE
        ORDER BY SortOrder
      ];
      String closedStatus;
      String openStatus = (String) defaults.get('Status');
      for (TaskStatus taskStatus : statuses) {
        if (taskStatus.IsClosed && closedStatus == null) {
          closedStatus = taskStatus.ApiName;
        }
        if (taskStatus.IsDefault && openStatus == null) {
          openStatus = taskStatus.ApiName;
        }
      }
      Boolean done = activityDate == null || activityDate <= repToday;
      return done && closedStatus != null ? closedStatus : openStatus;
    }

    /**
     * Fields the rep's layout or the database require that are not on the form: use the layout default, or stop with
     * a message for the admin instead of letting Salesforce reject the save without a field to highlight.
     */
    void fillServerRequired(Map<String, Object> task) {
      Set<String> required = new Set<String>(layoutRequired);
      for (String name : fieldInfos.keySet()) {
        Map<String, Object> info = (Map<String, Object>) fieldInfos.get(name);
        if (
          info.get('required') == true &&
          info.get('createable') == true &&
          info.get('dataType') != 'Boolean'
        ) {
          required.add(name);
        }
      }
      for (String name : required) {
        if (
          task.containsKey(name) ||
          byName.containsKey(name) ||
          SERVER_FIELDS.contains(name)
        ) {
          continue;
        }
        if (defaults.containsKey(name)) {
          task.put(name, defaults.get(name));
          continue;
        }
        Map<String, Object> info = (Map<String, Object>) fieldInfos.get(name);
        throw SalesReportException.of(
          SalesReportException.SAVE_FAILED,
          400,
          'Salesforce requires "' +
            (info == null ? name : (String) info.get('label')) +
            '" for this activity, but it is not on the LINE form. Ask your admin to add it to field set ' +
            FORM_FIELD_SET +
            '.'
        );
      }
    }
  }
}
