/**
 * Before-save rules of Sales Report LINE Links (D-44), for every change: the linking service, the Revoke button and
 * edits by an administrator.
 *
 * - The active keys follow the status: an Active link holds its User Id and LINE user ID in the two unique keys, an
 *   ended link holds neither. One active link per User and per LINE account is therefore enforced by the database.
 * - Ending a link (Active to Revoked or Unlinked) fills Unlinked At, Unlinked By (the administrator, never the Site
 *   guest) and a default Unlink Reason.
 * - An ended link keeps its status (it cannot be made Active again or re-ended), and the LINE user and Salesforce User of a link never change: every
 *   link is a new record, so the old ones stay as audit history.
 *
 * `with sharing`: it only sets fields on the records being saved and runs no queries.
 */
public with sharing class SalesReportLineLinkTriggerHandler {
  public static final String REASON_REVOKED = 'Revoked by admin';
  public static final String REASON_ADMIN = 'Admin';

  public static void beforeSave(
    List<SalesReport_Line_Link__c> links,
    Map<Id, SalesReport_Line_Link__c> oldById
  ) {
    for (SalesReport_Line_Link__c link : links) {
      SalesReport_Line_Link__c old = oldById == null
        ? null
        : oldById.get(link.Id);
      if (old != null && !checkUnchanged(link, old)) {
        continue;
      }
      Boolean active = link.Status__c == SalesReportLinkService.STATUS_ACTIVE;
      link.Active_User_Key__c = active && link.User__c != null
        ? String.valueOf(link.User__c)
        : null;
      link.Active_Line_Key__c = active ? link.Line_User_Id__c : null;
      if (
        !active &&
        (old == null ||
        old.Status__c == SalesReportLinkService.STATUS_ACTIVE)
      ) {
        stampEnd(link);
      }
    }
  }

  /** False (with an error on the record) when an edit breaks the history rules. */
  private static Boolean checkUnchanged(
    SalesReport_Line_Link__c link,
    SalesReport_Line_Link__c old
  ) {
    if (
      link.Line_User_Id__c != old.Line_User_Id__c ||
      link.User__c != old.User__c
    ) {
      link.addError(System.Label.SalesReport_Link_Identity_Locked);
      return false;
    }
    if (
      old.Status__c != SalesReportLinkService.STATUS_ACTIVE &&
      link.Status__c != old.Status__c
    ) {
      link.Status__c.addError(System.Label.SalesReport_Link_Already_Ended);
      return false;
    }
    return true;
  }

  private static void stampEnd(SalesReport_Line_Link__c link) {
    if (link.Unlinked_At__c == null) {
      link.Unlinked_At__c = Datetime.now();
    }
    // The Site guest ends links of deactivated users; it is not a person, so Unlinked By stays blank then.
    if (link.Unlinked_By__c == null && UserInfo.getUserType() == 'Standard') {
      link.Unlinked_By__c = UserInfo.getUserId();
    }
    if (link.Unlink_Reason__c == null) {
      link.Unlink_Reason__c = link.Status__c ==
        SalesReportLinkService.STATUS_REVOKED
        ? REASON_REVOKED
        : REASON_ADMIN;
    }
  }
}
