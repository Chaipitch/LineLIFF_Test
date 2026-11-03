@IsTest
private class SalesReportOpportunityControllerTest {
  private static Map<String, Object> responseJson() {
    return (Map<String, Object>) JSON.deserializeUntyped(
      RestContext.response.responseBody.toString()
    );
  }

  private static void linkedRep() {
    SalesReport_Settings__c settings = SalesReportTestFactory.settings();
    settings.Eca_Consumer_Key__c = 'test-consumer-key';
    settings.Opportunity_Form_Enabled__c = true;
    update settings;
    SalesReportTestFactory.link(
      SalesReportTestFactory.LINE_USER_ID,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );
    SalesReportSessionCalloutService.testAccessToken = 'session-token';
    Test.setMock(
      HttpCalloutMock.class,
      SalesReportTestFactory.opportunityApiMock()
    );
  }

  private static RestRequest request(String method, String body) {
    RestRequest req = SalesReportTestFactory.restRequest(
      SalesReportIdentityService.TOKEN_HEADER,
      SalesReportTestFactory.ID_TOKEN
    );
    req.httpMethod = method;
    req.requestURI = '/salesreport/v1/opportunities';
    if (body != null) {
      req.requestBody = Blob.valueOf(body);
    }
    return req;
  }

  @IsTest
  static void getWithAccountIdListsOpportunities() {
    linkedRep();
    request('GET', null)
      .params.put('accountId', SalesReportTestFactory.ACCOUNT_ID);

    Test.startTest();
    SalesReportOpportunityController.getOpportunities();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    Assert.areEqual(
      1,
      ((List<Object>) responseJson().get('opportunities')).size(),
      'List'
    );
  }

  @IsTest
  static void getWithIdReturnsTheForm() {
    linkedRep();
    request('GET', null)
      .params.put('id', SalesReportTestFactory.OPPORTUNITY_ID);

    Test.startTest();
    SalesReportOpportunityController.getOpportunities();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    Assert.areEqual(
      5,
      ((List<Object>) responseJson().get('fields')).size(),
      'Fields'
    );
  }

  @IsTest
  static void getWithLookupSearchesTheField() {
    linkedRep();
    RestRequest req = request('GET', null);
    req.params.put('lookup', 'PreSales_Engineer__c');
    req.params.put('q', 'eng');

    Test.startTest();
    SalesReportOpportunityController.getOpportunities();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    Assert.areEqual(
      1,
      ((List<Object>) responseJson().get('records')).size(),
      'Users found'
    );
  }

  @IsTest
  static void postUpdatesTheOpportunity() {
    linkedRep();
    request(
      'POST',
      JSON.serialize(
        new Map<String, Object>{
          'id' => SalesReportTestFactory.OPPORTUNITY_ID,
          'accountId' => SalesReportTestFactory.ACCOUNT_ID,
          'values' => new Map<String, Object>{
            'StageName' => SalesReportTestFactory.openStages()[0],
            'Amount' => 10,
            'Next_Step_Due_Date__c' => '2027-01-31'
          }
        }
      )
    );

    Test.startTest();
    SalesReportOpportunityController.save();
    Test.stopTest();

    Assert.areEqual(200, RestContext.response.statusCode, 'OK');
    Assert.areEqual('Toyota – CRM renewal', responseJson().get('name'), 'Name');
  }

  @IsTest
  static void notLinkedAnswers403() {
    SalesReport_Settings__c settings = SalesReportTestFactory.settings(
      true,
      'WARN'
    );
    settings.Opportunity_Form_Enabled__c = true;
    update settings;
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    request('POST', '{}');

    Test.startTest();
    SalesReportOpportunityController.save();
    Test.stopTest();

    Assert.areEqual(403, RestContext.response.statusCode, 'Forbidden');
  }

  @IsTest
  static void notLinkedCannotList() {
    SalesReport_Settings__c settings = SalesReportTestFactory.settings(
      true,
      'WARN'
    );
    settings.Opportunity_Form_Enabled__c = true;
    update settings;
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, SalesReportTestFactory.verifyBody())
    );
    request('GET', null);

    Test.startTest();
    SalesReportOpportunityController.getOpportunities();
    Test.stopTest();

    Assert.areEqual(403, RestContext.response.statusCode, 'Forbidden');
  }

  @IsTest
  static void switchedOffRefusesBeforeAnyCallout() {
    SalesReportTestFactory.settings();
    SalesReportHttpMock mock = SalesReportTestFactory.opportunityApiMock();
    Test.setMock(HttpCalloutMock.class, mock);
    request('GET', null)
      .params.put('accountId', SalesReportTestFactory.ACCOUNT_ID);

    Test.startTest();
    SalesReportOpportunityController.getOpportunities();
    Test.stopTest();

    Assert.areEqual(403, RestContext.response.statusCode, 'Refused');
    Assert.isTrue(mock.requests.isEmpty(), 'No LINE or Salesforce callout');
  }
}
