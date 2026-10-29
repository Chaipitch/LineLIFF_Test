@IsTest
private class SalesReportLinkPageControllerTest {
  private static String newCode() {
    return new SalesReportLinkService()
      .createCode(
        SalesReportTestFactory.identity(SalesReportTestFactory.LINE_USER_ID)
      );
  }

  private static SalesReportLinkPageController open(String code) {
    PageReference page = Page.SalesReport_Link;
    page.getParameters().put('code', code);
    Test.setCurrentPage(page);
    return new SalesReportLinkPageController();
  }

  @IsTest
  static void repConfirmsAndIsLinked() {
    SalesReportTestFactory.settings();
    User rep = SalesReportTestFactory.rep('ok', true);
    String code = newCode();

    System.runAs(rep) {
      SalesReportLinkPageController controller = open(code);
      Assert.areEqual(
        SalesReportLinkPageController.STATE_CONFIRM,
        controller.state,
        'Asks first'
      );
      Assert.areEqual(
        SalesReportTestFactory.DISPLAY_NAME,
        controller.lineDisplayName,
        'Shows the LINE account'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM SalesReport_Line_Link__c WITH SYSTEM_MODE],
        'Opening alone changes nothing'
      );

      controller.confirm();

      Assert.areEqual(
        SalesReportLinkPageController.STATE_DONE,
        controller.state,
        'Done'
      );
      Assert.areEqual(
        'https://liff.line.me/' + SalesReportTestFactory.LIFF_ID,
        controller.returnUrl,
        'Back to LINE'
      );
    }
    SalesReport_Line_Link__c link = [
      SELECT User__c, Status__c
      FROM SalesReport_Line_Link__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(rep.Id, link.User__c, 'Linked to the logged-in rep');
  }

  @IsTest
  static void userWithoutSalesReportAccessIsRefused() {
    User rep = SalesReportTestFactory.rep('no', false);
    String code = newCode();

    System.runAs(rep) {
      SalesReportLinkPageController controller = open(code);
      Assert.areEqual(
        SalesReportLinkPageController.STATE_NOT_ALLOWED,
        controller.state,
        'Refused'
      );
      controller.confirm();
      Assert.areEqual(
        SalesReportLinkPageController.STATE_NOT_ALLOWED,
        controller.state,
        'Still refused'
      );
    }
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM SalesReport_Line_Link__c WITH SYSTEM_MODE],
      'Nothing linked'
    );
  }

  @IsTest
  static void invalidOrReusedCodeShowsInvalid() {
    User rep = SalesReportTestFactory.rep('bad', true);
    String code = newCode();

    System.runAs(rep) {
      Assert.areEqual(
        SalesReportLinkPageController.STATE_INVALID,
        open('nope').state,
        'Unknown code'
      );
      SalesReportLinkPageController first = open(code);
      SalesReportLinkPageController second = open(code);
      first.confirm();
      second.confirm();
      Assert.areEqual(
        SalesReportLinkPageController.STATE_DONE,
        first.state,
        'First wins'
      );
      Assert.areEqual(
        SalesReportLinkPageController.STATE_INVALID,
        second.state,
        'Second is rejected'
      );
    }
  }
}
