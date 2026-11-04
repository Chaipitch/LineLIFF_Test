@IsTest
private class SalesReportSettingsServiceTest {
  @IsTest
  static void defaultsWhenNoSettingsRecord() {
    Test.startTest();
    String channelId = SalesReportSettingsService.lineLoginChannelId();
    String liffId = SalesReportSettingsService.liffId();
    String level = SalesReportSettingsService.logLevel();
    Test.stopTest();

    Assert.isNull(channelId, 'Channel ID has no default');
    Assert.isNull(liffId, 'LIFF ID has no default');
    Assert.areEqual(
      SalesReportSettingsService.DEFAULT_LOG_LEVEL,
      level,
      'Default log level'
    );
    Assert.areEqual(
      SalesReportSettingsService.DEFAULT_JWT_CERTIFICATE,
      SalesReportSettingsService.jwtCertificateName(),
      'Default certificate'
    );
    Assert.isFalse(
      SalesReportSettingsService.attachmentsEnabled(),
      'Attachments off by default'
    );
    Assert.isFalse(
      SalesReportSettingsService.opportunityFormEnabled(),
      'Update Opportunity off by default'
    );
  }

  @IsTest
  static void readsOrgDefaults() {
    SalesReportTestFactory.settings(' info ');

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
      Line_Login_Channel_Id__c = '   '
    );

    Assert.isNull(
      SalesReportSettingsService.lineLoginChannelId(),
      'Blank channel ID is missing'
    );
  }

  @IsTest
  static void fixedValues() {
    Assert.areEqual(5, SalesReportSettingsService.linkCodeTtlMinutes(), 'TTL');
    Assert.areEqual(
      2,
      SalesReportSettingsService.accountSearchMinChars(),
      'Min chars'
    );
    Assert.areEqual(
      10,
      SalesReportSettingsService.accountSearchMaxResults(),
      'Max results'
    );
    Assert.areEqual(
      5,
      SalesReportSettingsService.attachmentMaxFiles(),
      'Files'
    );
    Assert.areEqual(4, SalesReportSettingsService.attachmentMaxSizeMb(), 'MB');
    Assert.areEqual(
      new List<String>{ 'jpg', 'jpeg', 'png', 'pdf' },
      SalesReportSettingsService.attachmentFileTypes(),
      'Types'
    );
    Assert.areEqual(
      60,
      SalesReportSettingsService.rateLimitPerMinute(),
      'Rate'
    );
  }

  @IsTest
  static void retentionFollowsSettingsWithinBounds() {
    Assert.areEqual(
      SalesReportSettingsService.DEFAULT_LOG_RETENTION_DAYS,
      SalesReportSettingsService.logRetentionDays(),
      'Default retention'
    );
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Log_Retention_Days__c = 999
    );
    SalesReportSettingsService.cached = null;
    Assert.areEqual(
      SalesReportSettingsService.MAX_LOG_RETENTION_DAYS,
      SalesReportSettingsService.logRetentionDays(),
      'Capped'
    );
  }
}
