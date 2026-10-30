@IsTest
private class SalesReportSettingsServiceTest {
  @IsTest
  static void defaultsWhenNoSettingsRecord() {
    Test.startTest();
    Boolean enabled = SalesReportSettingsService.isEnabled();
    String channelId = SalesReportSettingsService.lineLoginChannelId();
    String liffId = SalesReportSettingsService.liffId();
    String level = SalesReportSettingsService.logLevel();
    Test.stopTest();

    Assert.isTrue(enabled, 'No settings record must mean enabled');
    Assert.isNull(channelId, 'Channel ID has no default');
    Assert.isNull(liffId, 'LIFF ID has no default');
    Assert.areEqual(
      SalesReportSettingsService.DEFAULT_LOG_LEVEL,
      level,
      'Default log level'
    );
  }

  @IsTest
  static void readsOrgDefaults() {
    SalesReportTestFactory.settings(false, ' info ');

    Assert.isFalse(
      SalesReportSettingsService.isEnabled(),
      'Kill switch must be honoured'
    );
    Assert.areEqual(
      SalesReportTestFactory.CHANNEL_ID,
      SalesReportSettingsService.lineLoginChannelId(),
      'Channel ID'
    );
    Assert.areEqual(
      SalesReportTestFactory.LIFF_ID,
      SalesReportSettingsService.liffId(),
      'LIFF ID'
    );
    Assert.areEqual(
      'INFO',
      SalesReportSettingsService.logLevel(),
      'Level is trimmed and upper-cased'
    );
  }

  @IsTest
  static void blankValuesAreTreatedAsMissing() {
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Line_Login_Channel_Id__c = '   ',
      Enabled__c = true
    );

    Assert.isNull(
      SalesReportSettingsService.lineLoginChannelId(),
      'Blank channel ID is missing'
    );
    Assert.isTrue(SalesReportSettingsService.isEnabled(), 'Enabled');
  }

  @IsTest
  static void accountSearchBoundsFollowSettings() {
    Assert.areEqual(
      SalesReportSettingsService.DEFAULT_SEARCH_MIN_CHARS,
      SalesReportSettingsService.accountSearchMinChars(),
      'Default min chars'
    );
    SalesReportSettingsService.cached = null;
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Account_Search_Min_Chars__c = 3,
      Account_Search_Max_Results__c = 999
    );
    Assert.areEqual(
      3,
      SalesReportSettingsService.accountSearchMinChars(),
      'Min chars'
    );
    Assert.areEqual(
      SalesReportSettingsService.MAX_SEARCH_RESULTS,
      SalesReportSettingsService.accountSearchMaxResults(),
      'Capped'
    );
  }

  @IsTest
  static void attachmentLimitsFollowSettings() {
    Assert.areEqual(
      SalesReportSettingsService.DEFAULT_ATTACHMENT_MAX_FILES,
      SalesReportSettingsService.attachmentMaxFiles(),
      'Default count'
    );
    Assert.areEqual(
      SalesReportSettingsService.MAX_ATTACHMENT_SIZE_MB,
      SalesReportSettingsService.attachmentMaxSizeMb(),
      'Default size'
    );
    Assert.areEqual(
      new List<String>{ 'jpg', 'jpeg', 'png', 'pdf' },
      SalesReportSettingsService.attachmentFileTypes(),
      'Default types'
    );

    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Attachment_Max_Files__c = 50,
      Attachment_Max_Size_Mb__c = 9,
      Attachment_File_Types__c = ' .PNG, pdf ,,png'
    );
    SalesReportSettingsService.cached = null;

    Assert.areEqual(
      SalesReportSettingsService.MAX_ATTACHMENT_FILES,
      SalesReportSettingsService.attachmentMaxFiles(),
      'Count capped'
    );
    Assert.areEqual(
      SalesReportSettingsService.MAX_ATTACHMENT_SIZE_MB,
      SalesReportSettingsService.attachmentMaxSizeMb(),
      'Size capped'
    );
    Assert.areEqual(
      new List<String>{ 'png', 'pdf' },
      SalesReportSettingsService.attachmentFileTypes(),
      'Normalised, no duplicates'
    );
  }

  @IsTest
  static void rateLimitAndRetentionFollowSettings() {
    Assert.areEqual(
      SalesReportSettingsService.DEFAULT_RATE_LIMIT_PER_MINUTE,
      SalesReportSettingsService.rateLimitPerMinute(),
      'Default rate'
    );
    Assert.areEqual(
      SalesReportSettingsService.DEFAULT_LOG_RETENTION_DAYS,
      SalesReportSettingsService.logRetentionDays(),
      'Default retention'
    );
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Rate_Limit_Per_Minute__c = 5000,
      Log_Retention_Days__c = 7
    );
    SalesReportSettingsService.cached = null;
    Assert.areEqual(
      SalesReportSettingsService.MAX_RATE_LIMIT_PER_MINUTE,
      SalesReportSettingsService.rateLimitPerMinute(),
      'Rate capped'
    );
    Assert.areEqual(
      7,
      SalesReportSettingsService.logRetentionDays(),
      'Retention'
    );
  }
}
