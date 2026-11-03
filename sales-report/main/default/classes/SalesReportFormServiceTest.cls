@IsTest
private class SalesReportFormServiceTest {
  private static SalesReportOrgApiCalloutService api() {
    return new SalesReportOrgApiCalloutService('session-token');
  }

  private static SalesReportFormService opportunityForm() {
    return new SalesReportFormService(
      api(),
      Opportunity.SObjectType,
      SalesReportOpportunityService.FORM_FIELD_SET,
      SalesReportFormService.Purpose.EDIT_RECORD
    );
  }

  @IsTest
  static void editFormClearsFieldsSentEmptyAndSkipsUnsent() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.opportunityApiMock()
    );
    Test.startTest();
    SalesReportFormService form = opportunityForm();
    Test.stopTest();

    Map<String, String> errors = new Map<String, String>();
    Map<String, Object> values = form.values(
      new Map<String, Object>{
        'StageName' => SalesReportTestFactory.openStages()[0],
        'Amount' => 5,
        'Next_Step_Due_Date__c' => '2027-01-31',
        'Next_Step_Custom__c' => ' '
      },
      errors
    );
    Assert.isTrue(errors.isEmpty(), 'No errors: ' + errors);
    Assert.isTrue(
      values.containsKey('Next_Step_Custom__c'),
      'Sent empty → cleared'
    );
    Assert.isNull(values.get('Next_Step_Custom__c'), 'Null clears');

    values = form.values(
      new Map<String, Object>{
        'StageName' => SalesReportTestFactory.openStages()[0],
        'Amount' => 5,
        'Next_Step_Due_Date__c' => '2027-01-31'
      },
      errors
    );
    Assert.isFalse(
      values.containsKey('Next_Step_Custom__c'),
      'Not sent → untouched'
    );
    Assert.isFalse(
      form.byName.containsKey('PreSales_Engineer__c'),
      'Forms that cannot search leave lookups out'
    );
  }

  @IsTest
  static void fieldNotOnTheFormStopsTheRequest() {
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.opportunityApiMock()
    );
    Test.startTest();
    SalesReportFormService form = opportunityForm();
    Test.stopTest();
    try {
      form.values(
        new Map<String, Object>{ 'OwnerId' => '005000000000001AAA' },
        new Map<String, String>()
      );
      Assert.fail('Expected INVALID_INPUT');
    } catch (SalesReportException e) {
      Assert.isTrue(e.getMessage().contains('OwnerId'), 'Names the field');
    }
  }

  @IsTest
  static void missingFieldSetIsAConfigError() {
    try {
      new SalesReportFormService(
        api(),
        Opportunity.SObjectType,
        'SalesReport_No_Such_Set',
        SalesReportFormService.Purpose.EDIT_RECORD
      );
      Assert.fail('Expected CONFIG_MISSING');
    } catch (SalesReportException e) {
      Assert.areEqual(SalesReportException.CONFIG_MISSING, e.code, 'Code');
    }
  }

  @IsTest
  static void bodyHelpersRejectBadShapes() {
    Assert.areEqual(
      'x',
      SalesReportFormService.stringOf(
        new Map<String, Object>{ 'a' => 'x' },
        'a'
      ),
      'String'
    );
    Assert.isNull(
      SalesReportFormService.stringOf(new Map<String, Object>{ 'a' => 1 }, 'a'),
      'Not a string'
    );
    Assert.isTrue(SalesReportFormService.valuesOf(null).isEmpty(), 'No values');
  }
}
