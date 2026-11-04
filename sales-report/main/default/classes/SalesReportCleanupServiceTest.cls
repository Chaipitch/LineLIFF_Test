@IsTest
private class SalesReportCleanupServiceTest {
  @IsTest
  static void deletesOnlyExpiredAndOldRows() {
    Datetime now = Datetime.now();
    Database.insert(
      new List<SObject>{
        new SalesReport_Link_Code__c(
          Code_Hash__c = 'a'.repeat(64),
          Line_User_Id__c = SalesReportTestFactory.LINE_USER_ID,
          Expires_At__c = now.addDays(-2)
        ),
        new SalesReport_Link_Code__c(
          Code_Hash__c = 'b'.repeat(64),
          Line_User_Id__c = SalesReportTestFactory.LINE_USER_ID,
          Expires_At__c = now.addMinutes(-5)
        )
      },
      AccessLevel.SYSTEM_MODE
    );
    List<SalesReport_Log__c> logs = new List<SalesReport_Log__c>{
      new SalesReport_Log__c(Level__c = 'WARN', Source__c = 'old'),
      new SalesReport_Log__c(Level__c = 'WARN', Source__c = 'new')
    };
    Database.insert(logs, AccessLevel.SYSTEM_MODE);
    Test.setCreatedDate(
      logs[0].Id,
      now.addDays(-SalesReportSettingsService.logRetentionDays() - 1)
    );

    Test.startTest();
    Map<String, Integer> deleted = new SalesReportCleanupService().run();
    Test.stopTest();

    Assert.areEqual(1, deleted.get('linkCodes'), 'Expired code');
    Assert.areEqual(1, deleted.get('logs'), 'Old log');
    Assert.isFalse(
      deleted.containsKey('rateLimits'),
      'Counters are in the cache'
    );
    Assert.areEqual(
      'b'.repeat(64),
      [SELECT Code_Hash__c FROM SalesReport_Link_Code__c WITH SYSTEM_MODE]
      .Code_Hash__c,
      'Fresh code kept'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM SalesReport_Log__c
        WHERE Source__c = 'new'
        WITH SYSTEM_MODE
      ],
      'New log kept'
    );
  }

  @IsTest
  static void schedulesNightlyAndRunsAsJob() {
    Test.startTest();
    String jobId = SalesReportCleanupService.schedule(
      SalesReportCleanupService.JOB_NAME + ' (test)'
    );
    Test.stopTest();

    CronTrigger job = [
      SELECT CronExpression, CronJobDetail.Name
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    Assert.areEqual(SalesReportCleanupService.CRON, job.CronExpression, 'Cron');
    Assert.areEqual(
      SalesReportCleanupService.JOB_NAME + ' (test)',
      job.CronJobDetail.Name,
      'Name'
    );
  }

  @IsTest
  static void nothingToDeleteIsFine() {
    Map<String, Integer> deleted = new SalesReportCleanupService().run();
    Assert.areEqual(0, deleted.get('linkCodes'), 'Codes');
    Assert.areEqual(0, deleted.get('logs'), 'Logs');
    Assert.areEqual(2, deleted.size(), 'Only codes and logs (counters expire in the cache)');
  }
}
