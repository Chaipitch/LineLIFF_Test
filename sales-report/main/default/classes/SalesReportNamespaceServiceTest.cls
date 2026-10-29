@IsTest
private class SalesReportNamespaceServiceTest {
  @IsTest
  static void emptyWhenUnpackaged() {
    Assert.areEqual('', SalesReportNamespaceService.namespace(), 'Unpackaged');
    Assert.areEqual(
      '',
      SalesReportNamespaceService.restPathPrefix(),
      'REST path'
    );
    Assert.areEqual(
      '/apex/SalesReport_Link',
      SalesReportNamespaceService.pagePath('SalesReport_Link'),
      'Page path'
    );
  }
}
