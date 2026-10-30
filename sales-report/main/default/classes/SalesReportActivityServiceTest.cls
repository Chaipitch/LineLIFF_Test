@IsTest
private class SalesReportActivityServiceTest {
  private static final String ACCOUNT_ID = '001000000000001AAA';

  private static SalesReportOrgApiCalloutService api() {
    return new SalesReportOrgApiCalloutService('session-token', 'Asia/Bangkok');
  }

  private static String body(String accountId, Map<String, Object> values) {
    return JSON.serialize(
      new Map<String, Object>{ 'accountId' => accountId, 'values' => values }
    );
  }

  private static Map<String, Object> visit(Date activityDate) {
    return new Map<String, Object>{
      'Type' => 'Visit',
      'ActivityDate' => String.valueOf(activityDate),
      'Description' => 'Met the IT manager.'
    };
  }

  private static Map<String, Object> sentTask(SalesReportHttpMock mock) {
    for (HttpRequest req : mock.requests) {
      if (req.getEndpoint().endsWith('/sobjects/Task')) {
        return (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
      }
    }
    Assert.fail('No Task was created');
    return null;
  }

  private static SalesReportException createExpectingFailure(String body) {
    try {
      new SalesReportActivityService().create(api(), body);
    } catch (SalesReportException e) {
      return e;
    }
    Assert.fail('Expected a SalesReportException');
    return null;
  }

  private static String closedStatus() {
    return [
      SELECT ApiName
      FROM TaskStatus
      WHERE IsClosed = TRUE
      WITH SYSTEM_MODE
      ORDER BY SortOrder
      LIMIT 1
    ]
    .ApiName;
  }

  @IsTest
  static void formFollowsFieldSetAndRepLayout() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.taskApiMock(
        SalesReportTestFactory.taskObjectInfoBody(
          SalesReportTestFactory.taskFieldInfos()
        ),
        SalesReportTestFactory.taskLayoutBody(
          new Set<String>{ 'Subject', 'Priority', 'Status', 'Description' }
        )
      )
    );

    Test.startTest();
    SalesReportActivityFormData form = new SalesReportActivityService()
      .form(api());
    Test.stopTest();

    Map<String, SalesReportActivityFormData.Field> byName = new Map<String, SalesReportActivityFormData.Field>();
    for (SalesReportActivityFormData.Field field : form.fields) {
      byName.put(field.name, field);
    }
    Assert.areEqual(
      new Set<String>{ 'Type', 'ActivityDate', 'Description' },
      byName.keySet(),
      'Field set members, no server fields'
    );
    Assert.areEqual('Comments', byName.get('Description').label, 'Org label');
    Assert.isTrue(
      byName.get('Description').required,
      'Required on the rep layout'
    );
    Assert.isFalse(byName.get('Type').required, 'Optional in Salesforce');
    Assert.areEqual('textarea', byName.get('Description').type, 'Type');
    Assert.areEqual(32000, byName.get('Description').maxLength, 'Length');
    Assert.areEqual('date', byName.get('ActivityDate').type, 'Date input');
    Assert.areEqual(2, byName.get('Type').options.size(), 'Picklist values');
    Assert.areEqual(
      'Customer Visit',
      byName.get('Type').options[0].label,
      'Picklist label'
    );
  }

  @IsTest
  static void formLeavesOutFieldsTheRepCannotCreate() {
    Map<String, Object> infos = SalesReportTestFactory.taskFieldInfos();
    infos.remove('Description');
    ((Map<String, Object>) infos.get('Type')).put('createable', false);
    SalesReportHttpMock mock = SalesReportTestFactory.taskApiMock(
      SalesReportTestFactory.taskObjectInfoBody(infos),
      SalesReportTestFactory.taskLayoutBody(new Set<String>())
    );
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportActivityFormData form = new SalesReportActivityService()
      .form(api());
    Test.stopTest();

    Assert.areEqual(1, form.fields.size(), 'Only the date is left');
    Assert.areEqual('ActivityDate', form.fields[0].name, 'Date');
  }

  @IsTest
  static void pastVisitIsCompletedTaskOnTheAccount() {
    SalesReportHttpMock mock = SalesReportTestFactory.taskApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportActivityData result = new SalesReportActivityService()
      .create(api(), body(ACCOUNT_ID, visit(Date.today().addDays(-2))));
    Test.stopTest();

    Assert.areEqual('00T000000000001EAA', result.id, 'Created Task ID');
    Map<String, Object> task = sentTask(mock);
    Assert.areEqual(ACCOUNT_ID, task.get('WhatId'), 'Linked to the Account');
    Assert.areEqual(
      'Customer Visit – Toyota Motor Thailand',
      task.get('Subject'),
      'Subject from Type label + Account'
    );
    Assert.areEqual(closedStatus(), task.get('Status'), 'Done → closed');
    Assert.areEqual('Normal', task.get('Priority'), 'Layout default');
    Assert.areEqual('Visit', task.get('Type'), 'Type value');
    Assert.isFalse(task.containsKey('OwnerId'), 'Owner defaults to the rep');
    Assert.areEqual(
      'Bearer session-token',
      mock.lastRequest.getHeader('Authorization'),
      'Created as the rep'
    );
  }

  @IsTest
  static void futureActivityKeepsTheOpenStatus() {
    SalesReportHttpMock mock = SalesReportTestFactory.taskApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportActivityData result = new SalesReportActivityService()
      .create(api(), body(ACCOUNT_ID, visit(Date.today().addDays(7))));
    Test.stopTest();

    Assert.areEqual('Open', result.status, 'Planned activity');
    Assert.areEqual('Open', sentTask(mock).get('Status'), 'Sent status');
  }

  @IsTest
  static void subjectUsesTaskLabelWithoutType() {
    SalesReportHttpMock mock = SalesReportTestFactory.taskApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    new SalesReportActivityService()
      .create(api(), body(ACCOUNT_ID, new Map<String, Object>()));
    Test.stopTest();

    Map<String, Object> task = sentTask(mock);
    Assert.areEqual(
      'Task – Toyota Motor Thailand',
      task.get('Subject'),
      'Object label'
    );
    Assert.areEqual(closedStatus(), task.get('Status'), 'No date → done');
  }

  @IsTest
  static void requiredFieldMissingIsHighlighted() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.taskApiMock(
        SalesReportTestFactory.taskObjectInfoBody(
          SalesReportTestFactory.taskFieldInfos()
        ),
        SalesReportTestFactory.taskLayoutBody(new Set<String>{ 'Description' })
      )
    );
    Map<String, Object> values = visit(Date.today());
    values.put('Description', '  ');

    Test.startTest();
    SalesReportException e = createExpectingFailure(body(ACCOUNT_ID, values));
    Test.stopTest();

    Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, 'Code');
    Assert.areEqual(400, e.statusCode, 'Status');
    Assert.areEqual(
      new Set<String>{ 'Description' },
      e.fieldErrors.keySet(),
      'Highlighted field'
    );
  }

  @IsTest
  static void invalidValuesAndAccountAreHighlighted() {
    Test.setMock(HttpCalloutMock.class, SalesReportTestFactory.taskApiMock());
    Map<String, Object> values = new Map<String, Object>{
      'Type' => 'Lunch',
      'ActivityDate' => '30/10/2026',
      'Description' => 'x'.repeat(32001)
    };

    Test.startTest();
    SalesReportException e = createExpectingFailure(body('not-an-id', values));
    Test.stopTest();

    Assert.areEqual(
      new Set<String>{ 'Type', 'ActivityDate', 'Description', 'accountId' },
      e.fieldErrors.keySet(),
      'Every bad value'
    );
  }

  @IsTest
  static void fieldOutsideTheFieldSetIsRejected() {
    Test.setMock(HttpCalloutMock.class, SalesReportTestFactory.taskApiMock());

    Test.startTest();
    SalesReportException e = createExpectingFailure(
      body(
        ACCOUNT_ID,
        new Map<String, Object>{ 'OwnerId' => '005000000000001AAA' }
      )
    );
    Test.stopTest();

    Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, 'Code');
    Assert.isTrue(e.getMessage().contains('OwnerId'), 'Names the field');
  }

  @IsTest
  static void accountTheRepCannotSeeIsRejected() {
    SalesReportHttpMock mock = SalesReportTestFactory.taskApiMock()
      .route('/query?q=', 200, '{"totalSize":0,"done":true,"records":[]}');
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportException e = createExpectingFailure(
      body(ACCOUNT_ID, visit(Date.today()))
    );
    Test.stopTest();

    Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, 'Code');
    Assert.isTrue(e.fieldErrors.containsKey('accountId'), 'Account field');
    for (HttpRequest req : mock.requests) {
      Assert.isFalse(
        req.getEndpoint().endsWith('/sobjects/Task'),
        'Nothing created'
      );
    }
  }

  @IsTest
  static void validationRuleMessageComesBack() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.taskApiMock()
        .route(
          '/sobjects/Task',
          400,
          '[{"message":"Comments must explain the next step.","errorCode":"FIELD_CUSTOM_VALIDATION_EXCEPTION","fields":["Description"]}]'
        )
    );

    Test.startTest();
    SalesReportException e = createExpectingFailure(
      body(ACCOUNT_ID, visit(Date.today()))
    );
    Test.stopTest();

    Assert.areEqual(SalesReportException.SAVE_FAILED, e.code, 'Code');
    Assert.areEqual(
      'Comments must explain the next step.',
      e.fieldErrors.get('Description'),
      'Message next to the field'
    );
  }

  @IsTest
  static void layoutRequiredFieldOffTheFormAsksForAdmin() {
    Map<String, Object> infos = SalesReportTestFactory.taskFieldInfos();
    infos.put(
      'Region__c',
      SalesReportTestFactory.fieldInfo('Picklist', 'Region', false, 255)
    );
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.taskApiMock(
        SalesReportTestFactory.taskObjectInfoBody(infos),
        SalesReportTestFactory.taskLayoutBody(
          new Set<String>{ 'Subject', 'Priority', 'Region__c' }
        )
      )
    );

    Test.startTest();
    SalesReportException e = createExpectingFailure(
      body(ACCOUNT_ID, visit(Date.today()))
    );
    Test.stopTest();

    Assert.areEqual(SalesReportException.SAVE_FAILED, e.code, 'Code');
    Assert.isTrue(e.getMessage().contains('"Region"'), 'Names the field');
    Assert.isTrue(
      e.getMessage().contains(SalesReportActivityService.FORM_FIELD_SET),
      'Tells the admin where to add it'
    );
  }

  @IsTest
  static void malformedBodyIsRejected() {
    for (String bad : new List<String>{ null, 'not json', '[1]' }) {
      SalesReportException e = createExpectingFailure(bad);
      Assert.areEqual(
        SalesReportException.INVALID_INPUT,
        e.code,
        'Body: ' + bad
      );
    }
    SalesReportException e = createExpectingFailure(
      '{"accountId":"' + ACCOUNT_ID + '","values":[1]}'
    );
    Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, 'values');
  }

  @IsTest
  static void coercesEachInputType() {
    Map<String, String> errors = new Map<String, String>();
    SalesReportActivityFormData.Field field = new SalesReportActivityFormData.Field();
    field.name = 'F';

    field.type = 'number';
    Assert.areEqual(
      12.5,
      SalesReportActivityService.coerced(field, '12.5', errors),
      'Number'
    );
    field.type = 'boolean';
    Assert.areEqual(
      true,
      SalesReportActivityService.coerced(field, true, errors),
      'Boolean'
    );
    field.type = 'multipicklist';
    field.options = new List<SalesReportActivityFormData.Option>();
    for (String value : new List<String>{ 'A', 'B' }) {
      SalesReportActivityFormData.Option option = new SalesReportActivityFormData.Option();
      option.value = value;
      option.label = value;
      field.options.add(option);
    }
    Assert.areEqual(
      'A;B',
      SalesReportActivityService.coerced(
        field,
        new List<Object>{ 'A', 'B' },
        errors
      ),
      'Multi-select'
    );
    Assert.isTrue(errors.isEmpty(), 'No errors so far');

    Assert.isNull(
      SalesReportActivityService.coerced(field, 'C', errors),
      'Unknown option'
    );
    field.type = 'number';
    Assert.isNull(
      SalesReportActivityService.coerced(field, 'abc', errors),
      'Not a number'
    );
    field.type = 'boolean';
    Assert.isNull(
      SalesReportActivityService.coerced(field, 'yes', errors),
      'Not a boolean'
    );
    Assert.areEqual(1, errors.size(), 'One field, last error wins');
  }
}
