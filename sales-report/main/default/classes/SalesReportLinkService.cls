/**
 * One-time linking of a LINE user to a Salesforce User (flow B) and lookup of the active link (flow A).
 *
 * `without sharing` with explicit SYSTEM_MODE (DATA-DICTIONARY §5.3, D-19, D-25): link codes are created from the Site
 * guest context and links are read there; links are written on behalf of the logged-in rep. Reps and the guest get
 * no object access, so mappings can only change through this class. Every LINE user ID used here comes from a
 * verified ID token; every Salesforce User ID is the running user's own (link page).
 */
public without sharing class SalesReportLinkService {
  public static final String STATUS_ACTIVE = 'Active';
  public static final String STATUS_UNLINKED = 'Unlinked';
  public static final String REASON_DEACTIVATED = 'User deactivated';
  public static final String REASON_REPLACED = 'Replaced by new LINE account';
  public static final String LINK_PAGE = 'SalesReport_Link';
  @TestVisible
  static final Integer MAX_CODE_LENGTH = 100;
  private static final Integer DISPLAY_NAME_LENGTH = 255;

  /** Creates a single-use code for a verified LINE user. Returns the code; only its SHA-256 hash is stored. */
  public String createCode(SalesReportLineVerifyData identity) {
    String code = EncodingUtil.base64Encode(Crypto.generateAesKey(256))
      .replace('+', '-')
      .replace('/', '_')
      .replace('=', '');
    Database.insert(
      new SalesReport_Link_Code__c(
        Code_Hash__c = hash(code),
        Line_User_Id__c = identity.sub,
        Line_Display_Name__c = identity.name == null
          ? null
          : identity.name.left(DISPLAY_NAME_LENGTH),
        Expires_At__c = Datetime.now()
          .addMinutes(SalesReportSettingsService.linkCodeTtlMinutes())
      ),
      AccessLevel.SYSTEM_MODE
    );
    return code;
  }

  /** Link page URL on the org's own domain; the rep logs in there (SSO/MFA as configured). */
  public static String linkPageUrl(String code) {
    return URL.getOrgDomainUrl().toExternalForm() +
      SalesReportNamespaceService.pagePath(LINK_PAGE) +
      '?code=' +
      EncodingUtil.urlEncode(code, 'UTF-8');
  }

  /** The code's record if it exists, is unused and has not expired; otherwise null. */
  public SalesReport_Link_Code__c findUsableCode(String code) {
    if (String.isBlank(code) || code.length() > MAX_CODE_LENGTH) {
      return null;
    }
    List<SalesReport_Link_Code__c> rows = [
      SELECT
        Id,
        Line_User_Id__c,
        Line_Display_Name__c,
        Expires_At__c,
        Used_At__c
      FROM SalesReport_Link_Code__c
      WHERE Code_Hash__c = :hash(code.trim())
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    return rows.isEmpty() || !isUsable(rows[0]) ? null : rows[0];
  }

  /**
   * Consumes the code and links its LINE user to userId (the logged-in rep). Any other LINE account of the same
   * User is unlinked (one active link per User); an existing link of this LINE user is moved to userId.
   */
  public SalesReport_Line_Link__c consume(String code, Id userId) {
    SalesReport_Link_Code__c found = findUsableCode(code);
    SalesReport_Link_Code__c locked = found == null
      ? null
      : [
          SELECT
            Id,
            Line_User_Id__c,
            Line_Display_Name__c,
            Expires_At__c,
            Used_At__c
          FROM SalesReport_Link_Code__c
          WHERE Id = :found.Id
          WITH SYSTEM_MODE
          FOR UPDATE
        ];
    if (locked == null || !isUsable(locked)) {
      throw SalesReportException.of(
        SalesReportException.LINK_CODE_INVALID,
        400,
        'The link code is unknown, expired or already used.'
      );
    }
    Datetime now = Datetime.now();
    locked.Used_At__c = now;
    locked.Used_By__c = userId;
    Database.update(locked, AccessLevel.SYSTEM_MODE);

    List<SalesReport_Line_Link__c> previous = [
      SELECT Id, Status__c
      FROM SalesReport_Line_Link__c
      WHERE
        Active_User_Key__c = :String.valueOf(userId)
        AND Line_User_Id__c != :locked.Line_User_Id__c
      WITH SYSTEM_MODE
      FOR UPDATE
    ];
    for (SalesReport_Line_Link__c old : previous) {
      old.Active_User_Key__c = null;
      if (old.Status__c == STATUS_ACTIVE) {
        old.Status__c = STATUS_UNLINKED;
        old.Unlinked_At__c = now;
        old.Unlink_Reason__c = REASON_REPLACED;
        old.Unlinked_By__c = userId;
      }
    }
    Database.update(previous, AccessLevel.SYSTEM_MODE);

    List<SalesReport_Line_Link__c> existing = [
      SELECT Id
      FROM SalesReport_Line_Link__c
      WHERE Line_User_Id__c = :locked.Line_User_Id__c
      WITH SYSTEM_MODE
      FOR UPDATE
    ];
    SalesReport_Line_Link__c link = existing.isEmpty()
      ? new SalesReport_Line_Link__c(Line_User_Id__c = locked.Line_User_Id__c)
      : existing[0];
    link.User__c = userId;
    link.Status__c = STATUS_ACTIVE;
    link.Active_User_Key__c = String.valueOf(userId);
    link.Linked_At__c = now;
    link.Line_Display_Name__c = locked.Line_Display_Name__c;
    link.Unlinked_At__c = null;
    link.Unlink_Reason__c = null;
    link.Unlinked_By__c = null;
    if (link.Id == null) {
      Database.insert(link, AccessLevel.SYSTEM_MODE);
    } else {
      Database.update(link, AccessLevel.SYSTEM_MODE);
    }
    return link;
  }

  /**
   * The active link of a LINE user, with its User's name, username and status; null when there is none. A link
   * whose User was deactivated is unlinked here (DML), so callers must make their callouts after this call only when
   * a link is returned.
   */
  public SalesReport_Line_Link__c findActiveLink(String lineUserId) {
    if (String.isBlank(lineUserId)) {
      return null;
    }
    List<SalesReport_Line_Link__c> rows = [
      SELECT
        Id,
        User__c,
        User__r.Name,
        User__r.Username,
        User__r.IsActive,
        User__r.TimeZoneSidKey
      FROM SalesReport_Line_Link__c
      WHERE Line_User_Id__c = :lineUserId AND Status__c = :STATUS_ACTIVE
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      return null;
    }
    SalesReport_Line_Link__c link = rows[0];
    if (link.User__c == null || link.User__r.IsActive != true) {
      Database.update(
        new SalesReport_Line_Link__c(
          Id = link.Id,
          Status__c = STATUS_UNLINKED,
          Active_User_Key__c = null,
          Unlinked_At__c = Datetime.now(),
          Unlink_Reason__c = REASON_DEACTIVATED
        ),
        AccessLevel.SYSTEM_MODE
      );
      return null;
    }
    return link;
  }

  @TestVisible
  static String hash(String code) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('SHA-256', Blob.valueOf(code))
    );
  }

  private static Boolean isUsable(SalesReport_Link_Code__c code) {
    return code.Used_At__c == null && code.Expires_At__c > Datetime.now();
  }
}
