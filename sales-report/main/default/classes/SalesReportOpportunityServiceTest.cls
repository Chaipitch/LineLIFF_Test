@IsTest
private class SalesReportOpportunityServiceTest {
  private static final String OPP_ID = SalesReportTestFactory.OPPORTUNITY_ID;
  private static final String ACCOUNT_ID = SalesReportTestFactory.ACCOUNT_ID;

  private static SalesReportOrgApiCalloutService api() {
    return new SalesReportOrgApiCalloutService(
      'session-token',
      'Asia/Bangkok',
      UserInfo.getUserId()
    );
  }

  private static String body(String accountId, Map<String, Object> values) {
    return JSON.serialize(
      new Map<String, Object>{
        'id' => OPP_ID,
        'accountId' => accountId,
        'values' => values
      }
    );
  }

  private static Map<String, Object> validValues() {
    return new Map<String, Object>{
      'StageName' => SalesReportTestFactory.openStages()[0],
      'Amount' => '1500000',
      'Next_Step_Custom__c' => '',
      'Next_Step_Due_Date__c' => '2027-01-31'
    };
  }

  private static HttpRequest updateRequest(SalesReportHttpMock mock) {
    for (HttpRequest req : mock.requests) {
      if (req.getEndpoint().contains('/sobjects/Opportunity/')) {
        return req;
      }
    }
    return null;
  }

  private static SalesReportException saveExpectingFailure(String body) {
    try {
      new SalesReportOpportunityService().save(api(), body);
    } catch (SalesReportException e) {
      return e;
    }
    Assert.fail('Expected a SalesReportException');
    return null;
  }

  @IsTest
  static void listsTheAccountsOpenOpportunitiesAsTheRep() {
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportOpportunityData data = new SalesReportOpportunityService()
      .listForAccount(api(), ACCOUNT_ID);
    Test.stopTest();

    Assert.areEqual(1, data.opportunities.size(), 'One opportunity');
    SalesReportOpportunityData.Item item = data.opportunities[0];
    Assert.areEqual(OPP_ID, item.id, 'ID');
    Assert.areEqual('Early Stage', item.stage, 'Stage label');
    Assert.areEqual('Rep One', item.ownerName, 'Owner');
    String soql = EncodingUtil.urlDecode(
      mock.lastRequest.getEndpoint().substringAfter('q='),
      'UTF-8'
    );
    Assert.isFalse(soql.contains('IsClosed = false'), 'Closed ones too (D-53)');
    Assert.isTrue(soql.contains('ORDER BY IsClosed'), 'Open first');
    Assert.isTrue(soql.contains(ACCOUNT_ID), 'This Account');
    Assert.areEqual(
      'Bearer session-token',
      mock.lastRequest.getHeader('Authorization'),
      'As the rep'
    );
  }

  @IsTest
  static void listNeedsAValidAccountId() {
    try {
      new SalesReportOpportunityService()
        .listForAccount(api(), '0010000; DELETE');
      Assert.fail('Expected INVALID_INPUT');
    } catch (SalesReportException e) {
      Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, 'Code');
    }
  }

  @IsTest
  static void formIsFilledWithCurrentValuesAndOpenStagesOnly() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.opportunityApiMock()
    );

    Test.startTest();
    SalesReportOpportunityFormData data = new SalesReportOpportunityService()
      .form(api(), OPP_ID);
    Test.stopTest();

    Assert.areEqual('Toyota – CRM renewal', data.name, 'Name');
    Map<String, SalesReportFormData.Field> byName = new Map<String, SalesReportFormData.Field>();
    for (SalesReportFormData.Field field : data.fields) {
      byName.put(field.name, field);
    }
    Assert.areEqual(
      new Set<String>{
        'StageName',
        'Amount',
        'PreSales_Engineer__c',
        'Next_Step_Custom__c',
        'Next_Step_Due_Date__c',
        'Update_CredenData_Screen_shot__c',
        'Please_articulate_the_reason_for_winning__c',
        'Attached_Signed_Contract_Documents__c',
        'Lost_Main_Reason__c',
        'Lost_Reason_Detail__c'
      },
      byName.keySet(),
      'Field set members'
    );
    SalesReportFormData.Field engineer = byName.get('PreSales_Engineer__c');
    Assert.areEqual('lookup', engineer.type, 'User lookup');
    Assert.areEqual('User', engineer.lookupObject, 'Searches Users');
    Assert.areEqual(UserInfo.getUserId(), engineer.defaultValue, 'Current ID');
    Assert.areEqual('Engineer One', engineer.displayValue, 'Current name');
    Assert.areEqual(
      '2026-12-15',
      byName.get('Next_Step_Due_Date__c').defaultValue,
      'Current date'
    );
    Assert.areEqual(
      'Send quote',
      byName.get('Next_Step_Custom__c').defaultValue,
      'Current text'
    );
    Assert.isTrue(byName.get('Amount').required, 'Required on the rep layout');
    Assert.areEqual('Target TCV', byName.get('Amount').label, 'Org label');
    Set<String> offered = new Set<String>();
    for (SalesReportFormData.Option option : byName.get('StageName').options) {
      offered.add(option.value);
    }
    Set<String> expected = new Set<String>(SalesReportTestFactory.openStages());
    for (
      String stage : new List<String>{
        SalesReportTestFactory.wonStage(),
        SalesReportTestFactory.lostStage()
      }
    ) {
      if (stage != null) {
        expected.add(stage);
      }
    }
    Assert.areEqual(
      expected,
      offered,
      'All active stages incl. closed ones (D-52); unknown values dropped'
    );
  }

  @IsTest
  static void updateSendsOnlyFormFieldsAsTheRep() {
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportOpportunityFormData result = new SalesReportOpportunityService()
      .save(api(), body(ACCOUNT_ID, validValues()));
    Test.stopTest();

    Assert.areEqual(OPP_ID, result.id, 'Updated ID');
    Assert.isNull(result.fields, 'No form in the result');
    HttpRequest req = updateRequest(mock);
    Assert.isNotNull(req, 'Update sent');
    Assert.isTrue(
      req.getEndpoint()
        .endsWith('/sobjects/Opportunity/' + OPP_ID + '?_HttpMethod=PATCH'),
      'PATCH override'
    );
    Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(
      req.getBody()
    );
    Assert.areEqual(1500000, sent.get('Amount'), 'Amount');
    Assert.areEqual('2027-01-31', sent.get('Next_Step_Due_Date__c'), 'Date');
    Assert.isTrue(
      sent.containsKey('Next_Step_Custom__c'),
      'Cleared field sent'
    );
    Assert.isNull(sent.get('Next_Step_Custom__c'), 'Cleared to null');
    Assert.areEqual(
      'Bearer session-token',
      req.getHeader('Authorization'),
      'As the rep'
    );
  }

  @IsTest
  static void opportunityOfAnotherAccountIsRefused() {
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock(
      SalesReportTestFactory.opportunityRecordBody(
        '001000000000009AAA',
        false,
        SalesReportTestFactory.openStages()[0]
      )
    );
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportException e = saveExpectingFailure(
      body(ACCOUNT_ID, validValues())
    );
    Test.stopTest();

    Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, 'Code');
    Assert.isNull(updateRequest(mock), 'Nothing updated');
  }

  @IsTest
  static void closedOpportunityCanBeUpdated() {
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock(
      SalesReportTestFactory.opportunityRecordBody(
        ACCOUNT_ID,
        true,
        'Closed Test'
      )
    );
    Test.setMock(HttpCalloutMock.class, mock);
    Map<String, Object> values = validValues();
    values.put('StageName', 'Closed Test');

    Test.startTest();
    new SalesReportOpportunityService().save(api(), body(ACCOUNT_ID, values));
    Test.stopTest();

    Assert.isNotNull(updateRequest(mock), 'Closed deals are updated (D-53)');
  }

  @IsTest
  static void unknownStageAndMissingRequiredAreHighlighted() {
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, mock);
    Map<String, Object> values = validValues();
    values.put('StageName', 'Closed Test');
    values.put('Amount', '');

    Test.startTest();
    SalesReportException e = saveExpectingFailure(body(ACCOUNT_ID, values));
    Test.stopTest();

    Assert.areEqual(
      new Set<String>{ 'StageName', 'Amount' },
      e.fieldErrors.keySet(),
      'Unknown stage not allowed, Amount required'
    );
    Assert.isNull(updateRequest(mock), 'Nothing updated');
  }

  @IsTest
  static void validationRuleMessageComesBack() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.opportunityApiMock()
        .route(
          '/sobjects/Opportunity/',
          400,
          '[{"message":"PreSales Engineer is required from stage 02.","errorCode":"FIELD_CUSTOM_VALIDATION_EXCEPTION","fields":[]}]'
        )
    );

    Test.startTest();
    SalesReportException e = saveExpectingFailure(
      body(ACCOUNT_ID, validValues())
    );
    Test.stopTest();

    Assert.areEqual(SalesReportException.SAVE_FAILED, e.code, 'Code');
    Assert.areEqual(
      'PreSales Engineer is required from stage 02.',
      e.getMessage(),
      'Org message shown'
    );
  }

  @IsTest
  static void badIdsAreRefusedBeforeAnyCallout() {
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, mock);
    for (
      String bad : new List<String>{
        '{"accountId":"' +
        ACCOUNT_ID +
        '"}',
        '{"id":"' +
        OPP_ID +
        '","accountId":"x"}',
        '{"id":"001000000000001AAA","accountId":"' +
        ACCOUNT_ID +
        '"}'
      }
    ) {
      SalesReportException e = saveExpectingFailure(bad);
      Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, bad);
    }
    try {
      new SalesReportOpportunityService().form(api(), 'nope');
      Assert.fail('Expected INVALID_INPUT');
    } catch (SalesReportException e) {
      Assert.areEqual(SalesReportException.INVALID_INPUT, e.code, 'Form id');
    }
    Assert.isTrue(mock.requests.isEmpty(), 'No callouts');
  }

  @IsTest
  static void repWithoutOpportunityAccessGetsNoAccess() {
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(
        400,
        '[{"message":"sObject type \'Opportunity\' is not supported.","errorCode":"INVALID_TYPE"}]'
      )
    );

    Test.startTest();
    try {
      new SalesReportOpportunityService().listForAccount(api(), ACCOUNT_ID);
      Assert.fail('Expected NO_ACCESS');
    } catch (SalesReportException e) {
      Assert.areEqual(SalesReportException.NO_ACCESS, e.code, 'Code');
      Assert.areEqual(403, e.statusCode, 'Status');
    }
    Test.stopTest();
  }

  @IsTest
  static void inactiveCurrentStageStaysSelectable() {
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock(
      SalesReportTestFactory.opportunityRecordBody(
        ACCOUNT_ID,
        false,
        'Old Stage'
      )
    );
    Test.setMock(HttpCalloutMock.class, mock);
    Map<String, Object> values = validValues();
    values.put('StageName', 'Old Stage');

    Test.startTest();
    SalesReportOpportunityFormData form = new SalesReportOpportunityService()
      .form(api(), OPP_ID);
    new SalesReportOpportunityService().save(api(), body(ACCOUNT_ID, values));
    Test.stopTest();

    for (SalesReportFormData.Field field : form.fields) {
      if (field.name == 'StageName') {
        Assert.areEqual(
          'Old Stage',
          field.options[0].value,
          'Current stage first'
        );
      }
    }
    Assert.isNotNull(updateRequest(mock), 'Saved with the unchanged old stage');
  }

  @IsTest
  static void lookupAcceptsOnlyARecordOfItsObject() {
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, mock);
    Map<String, Object> wrong = validValues();
    wrong.put('PreSales_Engineer__c', ACCOUNT_ID);

    Test.startTest();
    SalesReportException e = saveExpectingFailure(body(ACCOUNT_ID, wrong));
    Map<String, Object> right = validValues();
    right.put('PreSales_Engineer__c', UserInfo.getUserId());
    new SalesReportOpportunityService().save(api(), body(ACCOUNT_ID, right));
    Test.stopTest();

    Assert.isTrue(
      e.fieldErrors.containsKey('PreSales_Engineer__c'),
      'An Account ID is not a User'
    );
    Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(
      updateRequest(mock).getBody()
    );
    Assert.areEqual(
      UserInfo.getUserId(),
      sent.get('PreSales_Engineer__c'),
      'User ID saved'
    );
  }

  @IsTest
  static void lookupSearchFindsActiveUsersAsTheRep() {
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportLookupData data = new SalesReportOpportunityService()
      .searchLookup(api(), 'PreSales_Engineer__c', 'eng');
    Test.stopTest();

    Assert.areEqual(1, data.records.size(), 'One user');
    Assert.areEqual('Engineer One', data.records[0].name, 'Name');
    Assert.areEqual('PreSales', data.records[0].detail, 'Title');
    String query = EncodingUtil.urlDecode(
      mock.requests[mock.requests.size() - 1].getEndpoint(),
      'UTF-8'
    );
    Assert.isTrue(query.contains('IsActive = true'), query);
    Assert.isTrue(query.contains('LIKE \'%eng%\''), query);
  }

  @IsTest
  static void lookupSearchRefusesOtherFieldsAndShortTerms() {
    SalesReportOpportunityService service = new SalesReportOpportunityService();
    for (String field : new List<String>{ 'Name', 'StageName', null }) {
      try {
        service.searchLookup(api(), field, 'eng');
        Assert.fail('Expected a refusal for ' + field);
      } catch (SalesReportException e) {
        Assert.areEqual(
          SalesReportException.INVALID_INPUT,
          e.code,
          'Field ' + field
        );
      }
    }
    try {
      service.searchLookup(api(), 'PreSales_Engineer__c', 'e');
      Assert.fail('Expected QUERY_TOO_SHORT');
    } catch (SalesReportException e) {
      Assert.areEqual(SalesReportException.QUERY_TOO_SHORT, e.code, 'Short');
    }
  }

  private static Map<String, Object> sentUpdate(SalesReportHttpMock mock) {
    return (Map<String, Object>) JSON.deserializeUntyped(
      updateRequest(mock).getBody()
    );
  }

  @IsTest
  static void formHasScreenshotAndWonLostFieldsAfterStage() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.opportunityApiMock()
    );

    Test.startTest();
    SalesReportOpportunityFormData data = new SalesReportOpportunityService()
      .form(api(), OPP_ID);
    Test.stopTest();

    Integer stageAt;
    Map<String, SalesReportFormData.Field> byName = new Map<String, SalesReportFormData.Field>();
    for (Integer i = 0; i < data.fields.size(); i++) {
      byName.put(data.fields[i].name, data.fields[i]);
      if (data.fields[i].name == 'StageName') {
        stageAt = i;
      }
    }
    SalesReportFormData.Field screenshot = byName.get(
      'Update_CredenData_Screen_shot__c'
    );
    Assert.areEqual('image', screenshot.type, 'Rich text → screenshot');
    Assert.isTrue(screenshot.hasValue, 'Saved content reported');
    Assert.isNull(screenshot.defaultValue, 'Saved HTML not sent');
    SalesReportFormData.Field why = byName.get(
      'Please_articulate_the_reason_for_winning__c'
    );
    Assert.areEqual(
      'Please_articulate_the_reason_for_winning__c',
      data.fields[stageAt + 1].name,
      'Won fields right after Stage'
    );
    Assert.areEqual('StageName', why.showWhen.field, 'Depends on Stage');
    if (SalesReportTestFactory.wonStage() != null) {
      Assert.isTrue(
        why.showWhen.values.contains(SalesReportTestFactory.wonStage()),
        'Won stages'
      );
    }
    if (SalesReportTestFactory.lostStage() != null) {
      Assert.isTrue(
        byName.get('Lost_Main_Reason__c')
          .showWhen.values.contains(SalesReportTestFactory.lostStage()),
        'Lost stages'
      );
    }
  }

  @IsTest
  static void wonFieldsAreSavedOnlyWithAWonStage() {
    SalesReportHttpMock open = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, open);
    Map<String, Object> values = validValues();
    values.put('Please_articulate_the_reason_for_winning__c', 'Best fit');
    values.put('Attached_Signed_Contract_Documents__c', true);

    Test.startTest();
    new SalesReportOpportunityService().save(api(), body(ACCOUNT_ID, values));
    Map<String, Object> openSent = sentUpdate(open);
    String won = SalesReportTestFactory.wonStage();
    Map<String, Object> wonSent;
    if (won != null) {
      SalesReportHttpMock closing = SalesReportTestFactory.opportunityApiMock();
      Test.setMock(HttpCalloutMock.class, closing);
      values.put('StageName', won);
      new SalesReportOpportunityService().save(api(), body(ACCOUNT_ID, values));
      wonSent = sentUpdate(closing);
    }
    Test.stopTest();

    Assert.isFalse(
      openSent.containsKey('Please_articulate_the_reason_for_winning__c'),
      'Hidden for an open stage → not saved'
    );
    if (won != null) {
      Assert.areEqual(
        'Best fit',
        wonSent.get('Please_articulate_the_reason_for_winning__c'),
        'Saved with a won stage'
      );
      Assert.areEqual(
        true,
        wonSent.get('Attached_Signed_Contract_Documents__c'),
        'Checkbox'
      );
    }
  }

  @IsTest
  static void screenshotIsSavedAsAnImageAndNeverCleared() {
    SalesReportHttpMock withImage = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, withImage);
    Map<String, Object> values = validValues();
    values.put(
      'Update_CredenData_Screen_shot__c',
      'data:image/jpeg;base64,AAAA'
    );

    Test.startTest();
    new SalesReportOpportunityService().save(api(), body(ACCOUNT_ID, values));
    Map<String, Object> imageSent = sentUpdate(withImage);
    SalesReportHttpMock withoutImage = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, withoutImage);
    values.put('Update_CredenData_Screen_shot__c', '');
    new SalesReportOpportunityService().save(api(), body(ACCOUNT_ID, values));
    Map<String, Object> emptySent = sentUpdate(withoutImage);
    values.put('Update_CredenData_Screen_shot__c', 'javascript:alert(1)');
    SalesReportException bad = saveExpectingFailure(body(ACCOUNT_ID, values));
    Test.stopTest();

    Assert.isTrue(
      ((String) imageSent.get('Update_CredenData_Screen_shot__c'))
        .startsWith('<p><img src="data:image/jpeg;base64,AAAA"'),
      'Stored as an <img>'
    );
    Assert.isFalse(
      emptySent.containsKey('Update_CredenData_Screen_shot__c'),
      'Empty = keep the saved screenshot'
    );
    Assert.isTrue(
      bad.fieldErrors.containsKey('Update_CredenData_Screen_shot__c'),
      'Only image data URLs'
    );
  }
}
