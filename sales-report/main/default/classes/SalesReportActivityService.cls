/**
 * Log Activity (L5a): the form definition and the Task create, both **as the rep** (Option B).
 *
 * The form comes from field set SalesReport_Activity_Form on Task through SalesReportFormService (labels, picklists,
 * required flags from the rep's own layout and the database, D-31). Validation rules run on save; their messages come
 * back as SAVE_FAILED.
 *
 * The Task is linked to the chosen Opportunity of the Account, or to the Account itself ("Related To", D-54; was
 * Account only, D-33), and optionally to one of the Account's Contacts ("Name"). Subject is built from Type + Account
 * name, Status follows the date (D-32), other layout-required fields take the layout's defaults, OwnerId defaults to
 * the rep.
 */
public with sharing class SalesReportActivityService {
  public static final String FORM_FIELD_SET = 'SalesReport_Activity_Form';
  private static final String TASK_OBJECT = 'Task';
  /** Filled by the server (or by Salesforce), never required from the rep. */
  private static final Set<String> SERVER_FIELDS = new Set<String>{
    'Subject',
    'Status',
    'OwnerId',
    'WhatId',
    'WhoId'
  };
  @TestVisible
  static final Integer MAX_RELATED = 50;
  private static final Pattern ACCOUNT_ID = Pattern.compile(
    '001[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?'
  );
  private static final Pattern OPPORTUNITY_ID = Pattern.compile(
    '006[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?'
  );
  private static final Pattern CONTACT_ID = Pattern.compile(
    '003[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?'
  );

  /** The Account's Opportunities (open first) and Contacts the rep can see, for "Related To" and "Name" (D-54). */
  public SalesReportActivityRelatedData related(
    SalesReportOrgApiCalloutService api,
    String accountId
  ) {
    if (accountId == null || !ACCOUNT_ID.matcher(accountId).matches()) {
      throw SalesReportException.withFields(
        SalesReportException.INVALID_INPUT,
        400,
        'Choose an Account.',
        new Map<String, String>{ 'accountId' => 'Choose an Account.' }
      );
    }
    SalesReportActivityRelatedData data = new SalesReportActivityRelatedData();
    // accountId matched ACCOUNT_ID above, so it is safe to inline.
    for (
      Object row : api.query(
        'SELECT Id, Name, toLabel(StageName) FROM Opportunity WHERE AccountId = \'' +
          accountId +
          '\' ORDER BY IsClosed ASC, CloseDate ASC NULLS LAST LIMIT ' +
          MAX_RELATED
      )
    ) {
      data.opportunities.add(item((Map<String, Object>) row, 'StageName'));
    }
    for (
      Object row : api.query(
        'SELECT Id, Name, Title FROM Contact WHERE AccountId = \'' +
          accountId +
          '\' ORDER BY Name LIMIT ' +
          MAX_RELATED
      )
    ) {
      data.contacts.add(item((Map<String, Object>) row, 'Title'));
    }
    return data;
  }

  private static SalesReportActivityRelatedData.Item item(
    Map<String, Object> record,
    String detailField
  ) {
    SalesReportActivityRelatedData.Item item = new SalesReportActivityRelatedData.Item();
    item.id = (String) record.get('Id');
    item.name = (String) record.get('Name');
    item.detail = (String) record.get(detailField);
    return item;
  }

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
    String opportunityId = SalesReportFormService.stringOf(
      input,
      'opportunityId'
    );
    String contactId = SalesReportFormService.stringOf(input, 'contactId');

    SalesReportFormService context = formService(api);
    Map<String, String> errors = new Map<String, String>();
    Map<String, Object> task = context.values(submitted, errors);
    if (accountId == null || !ACCOUNT_ID.matcher(accountId).matches()) {
      errors.put('accountId', 'Choose an Account.');
    }
    if (
      String.isNotBlank(opportunityId) &&
      !OPPORTUNITY_ID.matcher(opportunityId).matches()
    ) {
      errors.put('opportunityId', 'Choose from the list.');
    }
    if (
      String.isNotBlank(contactId) && !CONTACT_ID.matcher(contactId).matches()
    ) {
      errors.put('contactId', 'Choose from the list.');
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
    if (String.isNotBlank(opportunityId)) {
      checkOnAccount(
        api,
        'Opportunity',
        opportunityId,
        accountId,
        'opportunityId'
      );
      task.put('WhatId', opportunityId);
    }
    if (String.isNotBlank(contactId)) {
      checkOnAccount(api, 'Contact', contactId, accountId, 'contactId');
      task.put('WhoId', contactId);
    }
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

  /** The record must exist, be visible to the rep and belong to the Account; INVALID_INPUT on that field otherwise. */
  private static void checkOnAccount(
    SalesReportOrgApiCalloutService api,
    String objectName,
    String recordId,
    String accountId,
    String fieldKey
  ) {
    // Both IDs matched their patterns and objectName is a constant, so this is safe to inline.
    List<Object> records = api.query(
      'SELECT Id FROM ' +
        objectName +
        ' WHERE Id = \'' +
        recordId +
        '\' AND AccountId = \'' +
        accountId +
        '\' LIMIT 1'
    );
    if (records.isEmpty()) {
      String message = objectName == 'Opportunity'
        ? 'This opportunity was not found on the chosen Account.'
        : 'This contact was not found on the chosen Account.';
      throw SalesReportException.withFields(
        SalesReportException.INVALID_INPUT,
        400,
        message,
        new Map<String, String>{ fieldKey => message }
      );
    }
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
