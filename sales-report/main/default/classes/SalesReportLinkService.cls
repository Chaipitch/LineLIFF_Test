/**
 * One-time linking of a LINE user to a Salesforce User (flow B) and lookup of the active link (flow A).
 *
 * `without sharing` with explicit SYSTEM_MODE (DATA-DICTIONARY §5.3, D-19, D-25): link codes are created from the Site
 * guest context and links are read there; links are written on behalf of the logged-in rep. Reps and the guest get
 * no object access, so mappings can only change through this class (and administrators, D-44). Every successful
 * link is a new record; the active keys and audit fields are kept by SalesReportLineLinkTriggerHandler. Every LINE user ID used here comes from a
 * verified ID token; every Salesforce User ID is the running user's own (link page).
 */
public without sharing class SalesReportLinkService {
  public static final String STATUS_ACTIVE = 'Active';
  public static final String STATUS_UNLINKED = 'Unlinked';
  public static final String STATUS_REVOKED = 'Revoked';
  public static final String REASON_DEACTIVATED = 'User deactivated';
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
   * Why a code can't be used: 'unknown', 'expired' or 'used'; null when it is usable. For the log only (never shown
   * with the code itself).
   */
  public String codeProblem(String code) {
    if (String.isBlank(code) || code.length() > MAX_CODE_LENGTH) {
      return 'unknown';
    }
    List<SalesReport_Link_Code__c> rows = [
      SELECT Expires_At__c, Used_At__c
      FROM SalesReport_Link_Code__c
      WHERE Code_Hash__c = :hash(code.trim())
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      return 'unknown';
    }
    if (rows[0].Used_At__c != null) {
      return 'used';
    }
    return rows[0].Expires_At__c > Datetime.now() ? null : 'expired';
  }

  /**
   * Why this LINE user can't be linked to userId (D-44): ALREADY_LINKED when the User already has an active link to
   * another LINE account, LINE_IN_USE when the LINE account is actively linked to another User; null when linking
   * may go ahead (including when exactly this pair is already linked). Existing links are never changed here.
   */
  public String conflict(String lineUserId, Id userId) {
    return conflictOf(
      [
        SELECT Id, Line_User_Id__c, User__c
        FROM SalesReport_Line_Link__c
        WHERE
          Active_User_Key__c = :String.valueOf(userId)
          OR Active_Line_Key__c = :lineUserId
        WITH SYSTEM_MODE
      ],
      lineUserId,
      userId
    );
  }

  /**
   * Consumes the code and links its LINE user to userId (the logged-in rep) with a new link record. Refused, with
   * the code left unused and every existing link untouched, when the User or the LINE account is already actively
   * linked to someone else (an administrator must revoke that link first). Linking a pair that is already linked
   * only uses up the code.
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
    List<SalesReport_Line_Link__c> active = [
      SELECT Id, Line_User_Id__c, User__c
      FROM SalesReport_Line_Link__c
      WHERE
        Active_User_Key__c = :String.valueOf(userId)
        OR Active_Line_Key__c = :locked.Line_User_Id__c
      WITH SYSTEM_MODE
      FOR UPDATE
    ];
    throwIfConflict(conflictOf(active, locked.Line_User_Id__c, userId));

    Datetime now = Datetime.now();
    locked.Used_At__c = now;
    locked.Used_By__c = userId;
    Database.update(locked, AccessLevel.SYSTEM_MODE);
    if (!active.isEmpty()) {
      return active[0];
    }

    SalesReport_Line_Link__c link = new SalesReport_Line_Link__c(
      Line_User_Id__c = locked.Line_User_Id__c,
      User__c = userId,
      Status__c = STATUS_ACTIVE,
      Linked_At__c = now,
      Line_Display_Name__c = locked.Line_Display_Name__c
    );
    Database.SaveResult result = Database.insert(
      link,
      false,
      AccessLevel.SYSTEM_MODE
    );
    if (!result.isSuccess()) {
      // A parallel Connect won the race for one of the unique active keys.
      for (Database.Error e : result.getErrors()) {
        if (e.getStatusCode() == StatusCode.DUPLICATE_VALUE) {
          throwIfConflict(conflict(locked.Line_User_Id__c, userId));
          SalesReport_Line_Link__c winner = findActiveLink(
            locked.Line_User_Id__c
          );
          if (winner != null) {
            return winner;
          }
        }
      }
      throw new DmlException(result.getErrors()[0].getMessage());
    }
    return link;
  }

  private static String conflictOf(
    List<SalesReport_Line_Link__c> active,
    String lineUserId,
    Id userId
  ) {
    for (SalesReport_Line_Link__c link : active) {
      if (link.User__c == userId && link.Line_User_Id__c != lineUserId) {
        return SalesReportException.ALREADY_LINKED;
      }
      if (link.User__c != userId && link.Line_User_Id__c == lineUserId) {
        return SalesReportException.LINE_IN_USE;
      }
    }
    return null;
  }

  private static void throwIfConflict(String conflict) {
    if (conflict == SalesReportException.ALREADY_LINKED) {
      throw SalesReportException.of(
        conflict,
        409,
        'This Salesforce user is already linked to another LINE account.'
      );
    }
    if (conflict == SalesReportException.LINE_IN_USE) {
      throw SalesReportException.of(
        conflict,
        409,
        'This LINE account is already linked to another Salesforce user.'
      );
    }
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
      WHERE Active_Line_Key__c = :lineUserId
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
