@IsTest
private class SalesReportLinkServiceTest {
  private static final String LINE_A = 'U' + 'a'.repeat(32);
  private static final String LINE_B = 'U' + 'b'.repeat(32);

  private static List<SalesReport_Line_Link__c> links() {
    return [
      SELECT
        Line_User_Id__c,
        User__c,
        Status__c,
        Active_User_Key__c,
        Unlink_Reason__c,
        Unlinked_At__c,
        Unlinked_By__c,
        Line_Display_Name__c
      FROM SalesReport_Line_Link__c
      WITH SYSTEM_MODE
      ORDER BY Line_User_Id__c
    ];
  }

  private static SalesReportException consumeExpectingFailure(String code) {
    try {
      new SalesReportLinkService().consume(code, UserInfo.getUserId());
    } catch (SalesReportException e) {
      return e;
    }
    Assert.fail('Expected a SalesReportException');
    return null;
  }

  @IsTest
  static void createCodeStoresOnlyTheHashWithExpiry() {
    SalesReportTestFactory.settings();

    String code = new SalesReportLinkService()
      .createCode(SalesReportTestFactory.identity(LINE_A));

    SalesReport_Link_Code__c row = [
      SELECT
        Code_Hash__c,
        Line_User_Id__c,
        Line_Display_Name__c,
        Expires_At__c,
        Used_At__c
      FROM SalesReport_Link_Code__c
      WITH SYSTEM_MODE
    ];
    Assert.isTrue(code.length() >= 40, 'At least 256 bits, base64url');
    Assert.isFalse(
      code.contains('+') || code.contains('/') || code.contains('='),
      'URL-safe'
    );
    Assert.areEqual(
      SalesReportLinkService.hash(code),
      row.Code_Hash__c,
      'Hash stored'
    );
    Assert.areNotEqual(code, row.Code_Hash__c, 'Code itself not stored');
    Assert.areEqual(LINE_A, row.Line_User_Id__c, 'LINE user');
    Assert.areEqual(
      SalesReportTestFactory.DISPLAY_NAME,
      row.Line_Display_Name__c,
      'Display name'
    );
    Assert.isTrue(
      row.Expires_At__c > Datetime.now().addMinutes(4),
      'Default TTL 5 minutes'
    );
    Assert.isTrue(
      row.Expires_At__c <= Datetime.now().addMinutes(5),
      'Not longer than TTL'
    );
    Assert.isNull(row.Used_At__c, 'Unused');
  }

  @IsTest
  static void linkPageUrlIsOnOrgDomain() {
    String linkUrl = SalesReportLinkService.linkPageUrl('abc-_1');
    Assert.isTrue(
      linkUrl.startsWith(
        URL.getOrgDomainUrl().toExternalForm() + '/apex/SalesReport_Link?code='
      ),
      linkUrl
    );
    Assert.isTrue(linkUrl.endsWith('abc-_1'), linkUrl);
  }

  @IsTest
  static void consumeCreatesActiveLinkAndMarksCodeUsed() {
    SalesReportLinkService service = new SalesReportLinkService();
    String code = service.createCode(SalesReportTestFactory.identity(LINE_A));

    Test.startTest();
    service.consume(code, UserInfo.getUserId());
    Test.stopTest();

    List<SalesReport_Line_Link__c> rows = links();
    Assert.areEqual(1, rows.size(), 'One link');
    Assert.areEqual(
      UserInfo.getUserId(),
      rows[0].User__c,
      'Linked to the running user'
    );
    Assert.areEqual(
      SalesReportLinkService.STATUS_ACTIVE,
      rows[0].Status__c,
      'Active'
    );
    Assert.areEqual(
      String.valueOf(UserInfo.getUserId()),
      rows[0].Active_User_Key__c,
      'Active key'
    );
    Assert.areEqual(
      SalesReportTestFactory.DISPLAY_NAME,
      rows[0].Line_Display_Name__c,
      'Display name copied'
    );
    SalesReport_Link_Code__c used = [
      SELECT Used_At__c, Used_By__c
      FROM SalesReport_Link_Code__c
      WITH SYSTEM_MODE
    ];
    Assert.isNotNull(used.Used_At__c, 'Code consumed');
    Assert.areEqual(UserInfo.getUserId(), used.Used_By__c, 'Consumed by');
    Assert.isNull(service.findUsableCode(code), 'Single use');
  }

  @IsTest
  static void codeCannotBeUsedTwice() {
    SalesReportLinkService service = new SalesReportLinkService();
    String code = service.createCode(SalesReportTestFactory.identity(LINE_A));
    service.consume(code, UserInfo.getUserId());

    SalesReportException e = consumeExpectingFailure(code);
    Assert.areEqual(
      SalesReportException.LINK_CODE_INVALID,
      e.code,
      'Second use rejected'
    );
  }

  @IsTest
  static void expiredUnknownBlankAndOversizedCodesAreRejected() {
    SalesReportLinkService service = new SalesReportLinkService();
    String code = service.createCode(SalesReportTestFactory.identity(LINE_A));
    SalesReport_Link_Code__c row = [
      SELECT Id
      FROM SalesReport_Link_Code__c
      WITH SYSTEM_MODE
    ];
    row.Expires_At__c = Datetime.now().addSeconds(-1);
    Database.update(row, AccessLevel.SYSTEM_MODE);

    Assert.isNull(service.findUsableCode(code), 'Expired');
    Assert.isNull(service.findUsableCode('unknown'), 'Unknown');
    Assert.isNull(service.findUsableCode(''), 'Blank');
    Assert.isNull(
      service.findUsableCode(
        'x'.repeat(SalesReportLinkService.MAX_CODE_LENGTH + 1)
      ),
      'Oversized'
    );
    Assert.areEqual(
      SalesReportException.LINK_CODE_INVALID,
      consumeExpectingFailure(code).code,
      'Expired code'
    );
    Assert.areEqual(0, links().size(), 'Nothing linked');
  }

  @IsTest
  static void newLineAccountReplacesTheUsersPreviousOne() {
    SalesReportTestFactory.link(
      LINE_A,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );
    SalesReportLinkService service = new SalesReportLinkService();
    String code = service.createCode(SalesReportTestFactory.identity(LINE_B));

    service.consume(code, UserInfo.getUserId());

    List<SalesReport_Line_Link__c> rows = links();
    Assert.areEqual(2, rows.size(), 'Old and new link');
    Assert.areEqual(
      SalesReportLinkService.STATUS_UNLINKED,
      rows[0].Status__c,
      'Old LINE account unlinked'
    );
    Assert.areEqual(
      SalesReportLinkService.REASON_REPLACED,
      rows[0].Unlink_Reason__c,
      'Reason'
    );
    Assert.isNull(rows[0].Active_User_Key__c, 'Key released');
    Assert.areEqual(
      UserInfo.getUserId(),
      rows[0].Unlinked_By__c,
      'Unlinked by the rep'
    );
    Assert.areEqual(
      SalesReportLinkService.STATUS_ACTIVE,
      rows[1].Status__c,
      'New LINE account active'
    );
  }

  @IsTest
  static void relinkingALineAccountMovesItAndClearsUnlinkFields() {
    User other = SalesReportTestFactory.rep('other', false);
    SalesReport_Line_Link__c old = SalesReportTestFactory.link(
      LINE_A,
      other.Id,
      SalesReportLinkService.STATUS_UNLINKED
    );
    old.Unlink_Reason__c = 'Admin';
    old.Unlinked_At__c = Datetime.now();
    Database.update(old, AccessLevel.SYSTEM_MODE);
    SalesReportLinkService service = new SalesReportLinkService();

    service.consume(
      service.createCode(SalesReportTestFactory.identity(LINE_A)),
      UserInfo.getUserId()
    );

    List<SalesReport_Line_Link__c> rows = links();
    Assert.areEqual(1, rows.size(), 'Same record reused');
    Assert.areEqual(
      UserInfo.getUserId(),
      rows[0].User__c,
      'Moved to the new user'
    );
    Assert.areEqual(
      SalesReportLinkService.STATUS_ACTIVE,
      rows[0].Status__c,
      'Active again'
    );
    Assert.isNull(rows[0].Unlink_Reason__c, 'Reason cleared');
    Assert.isNull(rows[0].Unlinked_At__c, 'Unlinked at cleared');
  }

  @IsTest
  static void findActiveLinkReturnsLinkWithUser() {
    SalesReportTestFactory.link(
      LINE_A,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );
    SalesReportTestFactory.link(
      LINE_B,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_UNLINKED
    );
    SalesReportLinkService service = new SalesReportLinkService();

    SalesReport_Line_Link__c link = service.findActiveLink(LINE_A);

    Assert.areEqual(UserInfo.getUserId(), link.User__c, 'User');
    Assert.areEqual(
      UserInfo.getUserName(),
      link.User__r.Username,
      'Username for the JWT'
    );
    Assert.isNull(service.findActiveLink(LINE_B), 'Unlinked does not count');
    Assert.isNull(service.findActiveLink('U' + 'c'.repeat(32)), 'Unknown');
    Assert.isNull(service.findActiveLink(null), 'Blank');
  }

  @IsTest
  static void deactivatedUserIsUnlinkedOnAccess() {
    User rep = SalesReportTestFactory.rep('gone', true);
    SalesReportTestFactory.link(
      LINE_A,
      rep.Id,
      SalesReportLinkService.STATUS_ACTIVE
    );
    System.runAs(new User(Id = UserInfo.getUserId())) {
      update new User(Id = rep.Id, IsActive = false);
    }

    Test.startTest();
    SalesReport_Line_Link__c link = new SalesReportLinkService()
      .findActiveLink(LINE_A);
    Test.stopTest();

    Assert.isNull(link, 'Deactivated users are not linked');
    SalesReport_Line_Link__c row = links()[0];
    Assert.areEqual(
      SalesReportLinkService.STATUS_UNLINKED,
      row.Status__c,
      'Unlinked'
    );
    Assert.areEqual(
      SalesReportLinkService.REASON_DEACTIVATED,
      row.Unlink_Reason__c,
      'Reason'
    );
    Assert.isNull(row.Active_User_Key__c, 'Key released');
  }

  @IsTest
  static void ttlFollowsSettingsWithinBounds() {
    insert new SalesReport_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Link_Code_Ttl_Minutes__c = 500
    );
    Assert.areEqual(
      SalesReportSettingsService.MAX_LINK_CODE_TTL_MINUTES,
      SalesReportSettingsService.linkCodeTtlMinutes(),
      'Capped'
    );
  }
}
