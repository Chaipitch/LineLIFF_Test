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
        ),
        new SalesReport_Rate_Limit__c(
          Key__c = 'c'.repeat(64),
          Window_Start__c = now.addDays(-2),
          Request_Count__c = 3
        ),
        new SalesReport_Rate_Limit__c(
          Key__c = 'd'.repeat(64),
          Window_Start__c = now,
          Request_Count__c = 1
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
    Assert.areEqual(1, deleted.get('rateLimits'), 'Old counter');
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
    Assert.areEqual(
      'd'.repeat(64),
      [SELECT Key__c FROM SalesReport_Rate_Limit__c WITH SYSTEM_MODE].Key__c,
      'Current counter kept'
    );
  }

  @IsTest
  static void schedulesNightlyAndRunsAsJob() {
    Test.startTest();
    String jobId = SalesReportCleanupService.schedule();
    Test.stopTest();

    CronTrigger job = [
      SELECT CronExpression, CronJobDetail.Name
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    Assert.areEqual(SalesReportCleanupService.CRON, job.CronExpression, 'Cron');
    Assert.areEqual(
      SalesReportCleanupService.JOB_NAME,
      job.CronJobDetail.Name,
      'Name'
    );
  }

  @IsTest
  static void nothingToDeleteIsFine() {
    Map<String, Integer> deleted = new SalesReportCleanupService().run();
    Assert.areEqual(0, deleted.get('linkCodes'), 'Codes');
    Assert.areEqual(0, deleted.get('logs'), 'Logs');
    Assert.areEqual(0, deleted.get('rateLimits'), 'Counters');
  }
}
