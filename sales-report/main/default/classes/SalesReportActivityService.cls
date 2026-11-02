/**
 * Log Activity (L5a): the form definition and the Task create, both **as the rep** (Option B).
 *
 * The form comes from field set SalesReport_Activity_Form on Task through SalesReportFormService (labels, picklists,
 * required flags from the rep's own layout and the database, D-31). Validation rules run on save; their messages come
 * back as SAVE_FAILED.
 *
 * The Task is linked to the Account only (D-33). Subject is built from Type + Account name, Status follows the date
 * (D-32), other layout-required fields take the layout's defaults, OwnerId defaults to the rep.
 */
public with sharing class SalesReportActivityService {
  public static final String FORM_FIELD_SET = 'SalesReport_Activity_Form';
  private static final String TASK_OBJECT = 'Task';
  /** Filled by the server (or by Salesforce), never required from the rep. */
  private static final Set<String> SERVER_FIELDS = new Set<String>{
    'Subject',
    'Status',
    'OwnerId',
    'WhatId'
  };
  private static final Pattern ACCOUNT_ID = Pattern.compile(
    '001[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?'
  );

  public SalesReportFormData form(SalesReportOrgApiCalloutService api) {
    return formService(api).form;
  }

  public SalesReportActivityData create(
    SalesReportOrgApiCalloutService api,
    String body
  ) {
    Map<String, Object> input = SalesReportFormService.parseBody(body);
    Map<String, Object> submitted = SalesReportFormService.valuesOf(
      input.get('values')
    );
    String accountId = SalesReportFormService.stringOf(input, 'accountId');

    SalesReportFormService context = formService(api);
    Map<String, String> errors = new Map<String, String>();
    Map<String, Object> task = context.values(submitted, errors);
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
      task.put('Subject', subject(context, task, accountName));
    }
    if (!context.byName.containsKey('Status')) {
      task.put(
        'Status',
        status(context, (Date) task.get('ActivityDate'), api.repToday())
      );
    }
    fillServerRequired(context, task);

    SalesReportActivityData result = new SalesReportActivityData();
    result.id = api.create(TASK_OBJECT, task);
    result.subject = (String) task.get('Subject');
    result.status = (String) task.get('Status');
    return result;
  }

  private static SalesReportFormService formService(
    SalesReportOrgApiCalloutService api
  ) {
    return new SalesReportFormService(
      api,
      Task.SObjectType,
      FORM_FIELD_SET,
      SalesReportFormService.Purpose.NEW_RECORD
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

  /** "<Type label> – <Account name>", or "<Task label> – <Account name>" without a Type. */
  private static String subject(
    SalesReportFormService context,
    Map<String, Object> task,
    String accountName
  ) {
    String prefix = context.objectLabel;
    SalesReportFormData.Field typeField = context.byName.get('Type');
    if (typeField != null && task.get('Type') != null) {
      prefix = (String) task.get('Type');
      for (SalesReportFormData.Option option : typeField.options) {
        if (option.value == task.get('Type')) {
          prefix = option.label;
        }
      }
    }
    Integer maxLength = 255;
    Map<String, Object> info = (Map<String, Object>) context.fieldInfos.get(
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
  private static String status(
    SalesReportFormService context,
    Date activityDate,
    Date repToday
  ) {
    List<TaskStatus> statuses = [
      SELECT ApiName, IsClosed, IsDefault
      FROM TaskStatus
      WITH SYSTEM_MODE
      ORDER BY SortOrder
    ];
    String closedStatus;
    String openStatus = (String) context.defaults.get('Status');
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
  private static void fillServerRequired(
    SalesReportFormService context,
    Map<String, Object> task
  ) {
    Set<String> required = new Set<String>(context.layoutRequired);
    for (String name : context.fieldInfos.keySet()) {
      Map<String, Object> info = (Map<String, Object>) context.fieldInfos.get(
        name
      );
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
        context.byName.containsKey(name) ||
        SERVER_FIELDS.contains(name)
      ) {
        continue;
      }
      if (context.defaults.containsKey(name)) {
        task.put(name, context.defaults.get(name));
        continue;
      }
      Map<String, Object> info = (Map<String, Object>) context.fieldInfos.get(
        name
      );
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
