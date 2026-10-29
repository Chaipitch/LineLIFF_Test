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
}
