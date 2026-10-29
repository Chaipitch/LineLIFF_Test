@IsTest
private class SalesReportLogServiceTest {
  @IsTest
  static void writesEntriesAtOrAboveTheConfiguredLevel() {
    SalesReportTestFactory.settings(true, 'WARN');

    Test.startTest();
    SalesReportLogService.setLineUserRef(SalesReportTestFactory.LINE_USER_ID);
    SalesReportLogService.error('Test.error', 'boom');
    SalesReportLogService.warn('Test.warn', 'careful');
    SalesReportLogService.info('Test.info', 'skipped');
    SalesReportLogService.debug('Test.debug', 'skipped');
    SalesReportLogService.flush();
    Test.stopTest();

    List<SalesReport_Log__c> logs = [
      SELECT
        Level__c,
        Source__c,
        Message__c,
        Line_User_Ref__c,
        User__c,
        Request_Id__c
      FROM SalesReport_Log__c
      WITH SYSTEM_MODE
      ORDER BY Level__c
    ];
    Assert.areEqual(
      2,
      logs.size(),
      'Only ERROR and WARN are written at level WARN'
    );
    Assert.areEqual('ERROR', logs[0].Level__c, 'Error entry');
    Assert.areEqual('Test.error', logs[0].Source__c, 'Source');
    Assert.areEqual('boom', logs[0].Message__c, 'Message');
    Assert.areEqual(
      SalesReportTestFactory.LINE_USER_ID.right(6),
      logs[0].Line_User_Ref__c,
      'Only the last 6 chars'
    );
    Assert.areEqual(
      UserInfo.getUserId(),
      logs[0].User__c,
      'Internal user is recorded'
    );
    Assert.isNotNull(logs[0].Request_Id__c, 'Request ID');
    Assert.isTrue(
      SalesReportLogService.BUFFER.isEmpty(),
      'Buffer is cleared after flush'
    );
  }

  @IsTest
  static void debugLevelWritesEverythingAndExceptionsAreFormatted() {
    SalesReportTestFactory.settings(true, 'DEBUG');

    SalesReportLogService.debug(null, null);
    SalesReportLogService.error('Test.exception', new DmlException('bad row'));
    SalesReportLogService.flush();

    List<SalesReport_Log__c> logs = [
      SELECT Level__c, Source__c, Message__c
      FROM SalesReport_Log__c
      WITH SYSTEM_MODE
      ORDER BY Name
    ];
    Assert.areEqual(2, logs.size(), 'Both entries written');
    Assert.areEqual('unknown', logs[0].Source__c, 'Blank source is replaced');
    Assert.isTrue(
      logs[1].Message__c.startsWith('System.DmlException: bad row'),
      logs[1].Message__c
    );
  }

  @IsTest
  static void longValuesAreTruncatedAndUnknownLevelFallsBack() {
    SalesReportTestFactory.settings(true, 'NOPE');

    SalesReportLogService.info('Test.info', 'not written at default WARN');
    SalesReportLogService.warn('S'.repeat(300), 'M'.repeat(40000));
    SalesReportLogService.flush();

    List<SalesReport_Log__c> logs = [
      SELECT Source__c, Message__c
      FROM SalesReport_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(1, logs.size(), 'Unknown level falls back to WARN');
    Assert.areEqual(255, logs[0].Source__c.length(), 'Source truncated');
    Assert.areEqual(32768, logs[0].Message__c.length(), 'Message truncated');
  }

  @IsTest
  static void flushWithNothingBufferedDoesNothing() {
    SalesReportLogService.flush();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM SalesReport_Log__c WITH SYSTEM_MODE],
      'Nothing written'
    );
  }
}
