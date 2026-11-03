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

      PageReference next = controller.confirm();
      Assert.areEqual(
        'https://liff.line.me/' + SalesReportTestFactory.LIFF_ID,
        next.getUrl(),
        'Straight back to the LIFF form'
      );
      Assert.isTrue(next.getRedirect(), 'Redirect, no done page');

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

  @IsTest
  static void malformedCodesAreDropped() {
    Assert.isNull(SalesReportLinkPageController.wellFormedCode(null), 'null');
    Assert.isNull(
      SalesReportLinkPageController.wellFormedCode('short'),
      'Too short'
    );
    Assert.isNull(
      SalesReportLinkPageController.wellFormedCode(
        '<script>alert(1)</script>xxxxxxxx'
      ),
      'Markup'
    );
    String ok = 'AbC-_' + 'x'.repeat(30);
    Assert.areEqual(
      ok,
      SalesReportLinkPageController.wellFormedCode(ok),
      'base64url kept'
    );
  }

  @IsTest
  static void returnsToTheFormTheRepStartedFrom() {
    SalesReportTestFactory.settings();
    PageReference page = Page.SalesReport_Link;
    page.getParameters().put('form', 'opportunity');
    Test.setCurrentPage(page);
    Assert.areEqual(
      'https://liff.line.me/' +
        SalesReportTestFactory.LIFF_ID +
        '?form=opportunity',
      new SalesReportLinkPageController().returnUrl,
      'Back to the chosen form'
    );

    page.getParameters().put('form', 'evil"><script>');
    Assert.areEqual(
      'https://liff.line.me/' + SalesReportTestFactory.LIFF_ID,
      new SalesReportLinkPageController().returnUrl,
      'Unknown form ignored'
    );
  }

  private static List<SalesReport_Log__c> logs() {
    return [
      SELECT Level__c, Source__c, Message__c
      FROM SalesReport_Log__c
      WITH SYSTEM_MODE
      ORDER BY Id
    ];
  }

  @IsTest
  static void repAlreadyLinkedToAnotherLineAccountIsToldToAskAnAdmin() {
    SalesReportTestFactory.settings();
    User rep = SalesReportTestFactory.rep('linked', true);
    SalesReportTestFactory.link(
      'U' + 'z'.repeat(32),
      rep.Id,
      SalesReportLinkService.STATUS_ACTIVE
    );
    String code = newCode();

    System.runAs(rep) {
      SalesReportLinkPageController controller = open(code);
      Assert.areEqual(
        SalesReportLinkPageController.STATE_ALREADY_LINKED,
        controller.state,
        'Refused before Connect'
      );
      Assert.isTrue(controller.hasRefusal, 'Page will log the refusal');
      Assert.isNull(controller.logVisit(), 'Stays on the page');
      controller.logVisit();
      Assert.isFalse(controller.hasRefusal, 'Logged once');
      // A Connect posted anyway (e.g. an old tab) is refused too.
      controller.confirm();
      Assert.areEqual(
        SalesReportLinkPageController.STATE_ALREADY_LINKED,
        controller.state,
        'Still refused'
      );
    }
    List<SalesReport_Log__c> rows = logs();
    Assert.areEqual(2, rows.size(), 'Both refusals logged');
    Assert.areEqual('WARN', rows[0].Level__c, 'WARN');
    Assert.isTrue(
      rows[0].Message__c.startsWith(SalesReportException.ALREADY_LINKED),
      rows[0].Message__c
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM SalesReport_Line_Link__c WITH SYSTEM_MODE],
      'Existing link kept, nothing added'
    );
  }

  @IsTest
  static void lineAccountLinkedToSomeoneElseIsRefused() {
    SalesReportTestFactory.settings();
    User other = SalesReportTestFactory.rep('owner', true);
    SalesReportTestFactory.link(
      SalesReportTestFactory.LINE_USER_ID,
      other.Id,
      SalesReportLinkService.STATUS_ACTIVE
    );
    User rep = SalesReportTestFactory.rep('second', true);
    String code = newCode();

    System.runAs(rep) {
      Assert.areEqual(
        SalesReportLinkPageController.STATE_LINE_IN_USE,
        open(code).state,
        'Refused'
      );
    }
  }

  @IsTest
  static void expiredOrUsedCodesAreLoggedWithTheReason() {
    User rep = SalesReportTestFactory.rep('late', true);
    String code = newCode();
    SalesReport_Link_Code__c row = [
      SELECT Id
      FROM SalesReport_Link_Code__c
      WITH SYSTEM_MODE
    ];
    row.Expires_At__c = Datetime.now().addSeconds(-1);
    Database.update(row, AccessLevel.SYSTEM_MODE);

    System.runAs(rep) {
      SalesReportLinkPageController controller = open(code);
      controller.logVisit();
      open(null).logVisit();
    }
    List<SalesReport_Log__c> rows = logs();
    Assert.areEqual(2, rows.size(), 'Both visits logged');
    Assert.isTrue(rows[0].Message__c.endsWith('expired'), rows[0].Message__c);
    Assert.isTrue(
      rows[1].Message__c.endsWith('missing or malformed'),
      rows[1].Message__c
    );
    Assert.isFalse(
      rows[0].Message__c.contains(code),
      'The code itself is never logged'
    );
  }

  @IsTest
  static void normalVisitWritesNoLog() {
    User rep = SalesReportTestFactory.rep('fine', true);
    String code = newCode();
    System.runAs(rep) {
      open(code).logVisit();
    }
    Assert.areEqual(0, logs().size(), 'Nothing to log');
  }
}
