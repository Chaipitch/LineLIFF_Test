@IsTest
private class SalesReportLineLinkTriggerHandlerTest {
  private static final String LINE_A = 'U' + 'a'.repeat(32);
  private static final String LINE_B = 'U' + 'b'.repeat(32);

  private static SalesReport_Line_Link__c reload(Id linkId) {
    return [
      SELECT
        Status__c,
        Active_User_Key__c,
        Active_Line_Key__c,
        Unlink_Reason__c,
        Unlinked_At__c,
        Unlinked_By__c
      FROM SalesReport_Line_Link__c
      WHERE Id = :linkId
      WITH SYSTEM_MODE
    ];
  }

  private static String saveError(SalesReport_Line_Link__c link) {
    Database.SaveResult result = Database.update(
      link,
      false,
      AccessLevel.SYSTEM_MODE
    );
    Assert.isFalse(result.isSuccess(), 'Save refused');
    return result.getErrors()[0].getMessage();
  }

  @IsTest
  static void activeLinkGetsBothKeys() {
    SalesReport_Line_Link__c link = SalesReportTestFactory.link(
      LINE_A,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );

    SalesReport_Line_Link__c row = reload(link.Id);
    Assert.areEqual(
      String.valueOf(UserInfo.getUserId()),
      row.Active_User_Key__c,
      'User key'
    );
    Assert.areEqual(LINE_A, row.Active_Line_Key__c, 'LINE key');
  }

  @IsTest
  static void revokeFillsTheAuditFieldsAndClearsTheKeys() {
    SalesReport_Line_Link__c link = SalesReportTestFactory.link(
      LINE_A,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );

    Test.startTest();
    Database.update(
      new SalesReport_Line_Link__c(
        Id = link.Id,
        Status__c = SalesReportLinkService.STATUS_REVOKED
      ),
      AccessLevel.SYSTEM_MODE
    );
    Test.stopTest();

    SalesReport_Line_Link__c row = reload(link.Id);
    Assert.isNull(row.Active_User_Key__c, 'User key cleared');
    Assert.isNull(row.Active_Line_Key__c, 'LINE key cleared');
    Assert.isNotNull(row.Unlinked_At__c, 'Unlinked at');
    Assert.areEqual(UserInfo.getUserId(), row.Unlinked_By__c, 'Unlinked by');
    Assert.areEqual(
      SalesReportLineLinkTriggerHandler.REASON_REVOKED,
      row.Unlink_Reason__c,
      'Default reason'
    );
  }

  @IsTest
  static void unlinkingByHandKeepsTheChosenReason() {
    SalesReport_Line_Link__c link = SalesReportTestFactory.link(
      LINE_A,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );
    SalesReport_Line_Link__c other = SalesReportTestFactory.link(
      LINE_B,
      SalesReportTestFactory.rep('other', false).Id,
      SalesReportLinkService.STATUS_ACTIVE
    );

    Database.update(
      new List<SalesReport_Line_Link__c>{
        new SalesReport_Line_Link__c(
          Id = link.Id,
          Status__c = SalesReportLinkService.STATUS_UNLINKED
        ),
        new SalesReport_Line_Link__c(
          Id = other.Id,
          Status__c = SalesReportLinkService.STATUS_REVOKED,
          Unlink_Reason__c = SalesReportLinkService.REASON_DEACTIVATED
        )
      },
      AccessLevel.SYSTEM_MODE
    );

    Assert.areEqual(
      SalesReportLineLinkTriggerHandler.REASON_ADMIN,
      reload(link.Id).Unlink_Reason__c,
      'Default for a hand-unlinked link'
    );
    Assert.areEqual(
      SalesReportLinkService.REASON_DEACTIVATED,
      reload(other.Id).Unlink_Reason__c,
      'Chosen reason kept'
    );
  }

  @IsTest
  static void endedLinkCannotBeReactivatedOrChanged() {
    SalesReport_Line_Link__c link = SalesReportTestFactory.link(
      LINE_A,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_REVOKED
    );

    Assert.areEqual(
      System.Label.SalesReport_Link_Already_Ended,
      saveError(
        new SalesReport_Line_Link__c(
          Id = link.Id,
          Status__c = SalesReportLinkService.STATUS_ACTIVE
        )
      ),
      'No reactivation'
    );
    Assert.areEqual(
      System.Label.SalesReport_Link_Already_Ended,
      saveError(
        new SalesReport_Line_Link__c(
          Id = link.Id,
          Status__c = SalesReportLinkService.STATUS_UNLINKED
        )
      ),
      'No re-ending'
    );
    Assert.isNull(reload(link.Id).Active_Line_Key__c, 'Still ended');
  }

  @IsTest
  static void lineUserAndSalesforceUserCannotChange() {
    SalesReport_Line_Link__c link = SalesReportTestFactory.link(
      LINE_A,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );
    User other = SalesReportTestFactory.rep('other', false);

    Assert.areEqual(
      System.Label.SalesReport_Link_Identity_Locked,
      saveError(new SalesReport_Line_Link__c(Id = link.Id, User__c = other.Id)),
      'User locked'
    );
    Assert.areEqual(
      System.Label.SalesReport_Link_Identity_Locked,
      saveError(
        new SalesReport_Line_Link__c(Id = link.Id, Line_User_Id__c = LINE_B)
      ),
      'LINE user locked'
    );
  }

  @IsTest
  static void secondActiveLinkIsRejectedByTheDatabase() {
    SalesReportTestFactory.link(
      LINE_A,
      UserInfo.getUserId(),
      SalesReportLinkService.STATUS_ACTIVE
    );

    Database.SaveResult sameUser = Database.insert(
      new SalesReport_Line_Link__c(
        Line_User_Id__c = LINE_B,
        User__c = UserInfo.getUserId(),
        Status__c = SalesReportLinkService.STATUS_ACTIVE
      ),
      false,
      AccessLevel.SYSTEM_MODE
    );
    Database.SaveResult sameLine = Database.insert(
      new SalesReport_Line_Link__c(
        Line_User_Id__c = LINE_A,
        User__c = SalesReportTestFactory.rep('other', false).Id,
        Status__c = SalesReportLinkService.STATUS_ACTIVE
      ),
      false,
      AccessLevel.SYSTEM_MODE
    );

    Assert.isFalse(sameUser.isSuccess(), 'One active link per User');
    Assert.areEqual(
      StatusCode.DUPLICATE_VALUE,
      sameUser.getErrors()[0].getStatusCode(),
      'Unique user key'
    );
    Assert.isFalse(sameLine.isSuccess(), 'One active link per LINE account');
  }
}
