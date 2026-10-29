@IsTest
private class SalesReportAccountServiceTest {
  private static String queryResponse(List<Map<String, Object>> records) {
    return JSON.serialize(
      new Map<String, Object>{
        'totalSize' => records.size(),
        'done' => true,
        'records' => records
      }
    );
  }

  private static Map<String, Object> account(String id, String name) {
    return new Map<String, Object>{ 'Id' => id, 'Name' => name };
  }

  @IsTest
  static void searchQueriesAsTheRepAndRanksPrefixMatchesFirst() {
    SalesReportHttpMock mock = new SalesReportHttpMock(
      200,
      queryResponse(
        new List<Map<String, Object>>{
          account('001000000000001AAA', 'Big Toyota Dealer'),
          account('001000000000002AAA', 'Toyota Motor Thailand'),
          account('001000000000003AAA', 'Toyota Tsusho')
        }
      )
    );
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SalesReportAccountData data = new SalesReportAccountService()
      .search(new SalesReportOrgApiCalloutService('session-token'), '  toy ');
    Test.stopTest();

    Assert.areEqual(3, data.accounts.size(), 'All matches');
    Assert.areEqual(
      'Toyota Motor Thailand',
      data.accounts[0].name,
      'Prefix first'
    );
    Assert.areEqual(
      'Toyota Tsusho',
      data.accounts[1].name,
      'Prefix, then order'
    );
    Assert.areEqual(
      'Big Toyota Dealer',
      data.accounts[2].name,
      'Contains last'
    );
    Assert.areEqual(
      '001000000000002AAA',
      data.accounts[0].id,
      'Account ID returned'
    );
    String endpoint = EncodingUtil.urlDecode(
      mock.lastRequest.getEndpoint(),
      'UTF-8'
    );
    Assert.isTrue(
      endpoint.contains(
        '/services/data/' +
          SalesReportOrgApiCalloutService.API_VERSION +
          '/query?q='
      ),
      endpoint
    );
    Assert.isTrue(
      endpoint.contains('Name LIKE \'%toy%\''),
      'Trimmed term: ' + endpoint
    );
    Assert.areEqual(
      'Bearer session-token',
      mock.lastRequest.getHeader('Authorization'),
      'As the rep'
    );
  }

  @IsTest
  static void resultsAreCappedBySettings() {
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Account_Search_Max_Results__c = 2
    );
    List<Map<String, Object>> rows = new List<Map<String, Object>>();
    for (Integer i = 0; i < 5; i++) {
      rows.add(account('00100000000000' + i + 'AAA', 'Acme ' + i));
    }
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, queryResponse(rows))
    );

    Test.startTest();
    SalesReportAccountData data = new SalesReportAccountService()
      .search(new SalesReportOrgApiCalloutService('t'), 'acme');
    Test.stopTest();

    Assert.areEqual(2, data.accounts.size(), 'Max results from settings');
  }

  @IsTest
  static void tooShortTermIsRejectedWithoutCallout() {
    SalesReportHttpMock mock = new SalesReportHttpMock(
      200,
      queryResponse(new List<Map<String, Object>>())
    );
    Test.setMock(HttpCalloutMock.class, mock);
    try {
      new SalesReportAccountService()
        .search(new SalesReportOrgApiCalloutService('t'), ' a ');
      Assert.fail('Expected QUERY_TOO_SHORT');
    } catch (SalesReportException e) {
      Assert.areEqual(
        SalesReportException.QUERY_TOO_SHORT,
        e.code,
        'Too short'
      );
      Assert.areEqual(400, e.statusCode, 'Status');
    }
    Assert.isNull(mock.lastRequest, 'No callout');
  }

  @IsTest
  static void quotesBackslashesAndWildcardsAreEscaped() {
    String soql = SalesReportAccountService.soql(
      'a\'b\\c%d_e',
      new List<String>()
    );
    Assert.areEqual(
      'SELECT Id, Name FROM Account WHERE Name LIKE \'%a\\\'b\\\\c\\%d\\_e%\' ORDER BY Name LIMIT 50',
      soql,
      'Escaped term'
    );
  }

  @IsTest
  static void extraFieldsAreSearchedAndShownAsDetail() {
    String soql = SalesReportAccountService.soql(
      'abc',
      new List<String>{ 'AccountNumber' }
    );
    Assert.isTrue(
      soql.startsWith('SELECT Id, Name, AccountNumber FROM Account'),
      soql
    );
    Assert.isTrue(soql.contains('OR AccountNumber LIKE \'%abc%\''), soql);

    Map<String, Object> row = account('001000000000001AAA', 'Zeta');
    row.put('AccountNumber', 'ABC-1');
    SalesReportAccountData data = SalesReportAccountService.ranked(
      new List<Object>{ row },
      'abc',
      new List<String>{ 'AccountNumber' }
    );
    Assert.areEqual(
      'ABC-1',
      data.accounts[0].detail,
      'Detail from the extra field'
    );
  }

  @IsTest
  static void fieldSetProvidesOnlyExtraTextFields() {
    for (String field : SalesReportAccountService.extraSearchFields()) {
      Assert.areNotEqual(
        'Name',
        field,
        'Name is always searched, not repeated'
      );
    }
    Assert.areEqual(
      'abc',
      SalesReportAccountService.normalised(' a b c '.replace(' ', '')),
      'Normalised'
    );
    Assert.areEqual(
      SalesReportAccountService.MAX_TERM_LENGTH,
      SalesReportAccountService.normalised('x'.repeat(200)).length(),
      'Capped length'
    );
  }

  @IsTest
  static void emptyResultIsEmptyList() {
    Test.setMock(
      HttpCalloutMock.class,
      new SalesReportHttpMock(200, '{"totalSize":0,"done":true}')
    );
    SalesReportAccountData data = new SalesReportAccountService()
      .search(new SalesReportOrgApiCalloutService('t'), 'nothing');
    Assert.areEqual(0, data.accounts.size(), 'No accounts');
  }
}
