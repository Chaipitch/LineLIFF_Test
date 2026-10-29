@IsTest
private class SalesReportLiffPageControllerTest {
  @IsTest
  static void configContainsLiffIdApiBaseAndLabels() {
    SalesReportTestFactory.settings();

    Test.startTest();
    SalesReportLiffPageController controller = new SalesReportLiffPageController();
    Test.stopTest();

    Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(
      controller.configJson
    );
    Assert.areEqual(
      SalesReportTestFactory.LIFF_ID,
      config.get('liffId'),
      'LIFF ID'
    );
    Assert.areEqual(true, config.get('enabled'), 'Enabled');
    Assert.areEqual(
      '/services/apexrest/salesreport/v1',
      config.get('apiBase'),
      'No Site prefix and no namespace in tests'
    );
    Map<String, Object> labels = (Map<String, Object>) config.get('labels');
    Assert.areEqual(
      System.Label.SalesReport_Hello,
      labels.get('hello'),
      'Labels come from Custom Labels'
    );
    Assert.areEqual(18, labels.size(), 'All page labels');
  }

  @IsTest
  static void configWithoutSettingsHasNoLiffId() {
    SalesReportLiffPageController controller = new SalesReportLiffPageController();

    Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(
      controller.configJson
    );
    Assert.isNull(
      config.get('liffId'),
      'Page shows "unavailable" without a LIFF ID'
    );
  }
}
