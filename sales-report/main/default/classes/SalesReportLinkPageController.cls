/**
 * Controller of the SalesReport_Link page (login required, not on the Site). Shows which LINE account is about to be
 * connected and links it to the logged-in rep only after an explicit Confirm (a POST protected by Visualforce's CSRF
 * token), so opening a link alone never changes anything.
 */
public with sharing class SalesReportLinkPageController {
  public static final String STATE_CONFIRM = 'CONFIRM';
  public static final String STATE_DONE = 'DONE';
  public static final String STATE_INVALID = 'INVALID';
  public static final String STATE_NOT_ALLOWED = 'NOT_ALLOWED';
  /** The rep's Salesforce user already has an active link to another LINE account (D-44). */
  public static final String STATE_ALREADY_LINKED = 'ALREADY_LINKED';
  /** This LINE account is actively linked to another Salesforce user (D-44). */
  public static final String STATE_LINE_IN_USE = 'LINE_IN_USE';
  /** Unexpected failure; the page shows the request ID as a support reference (D-45). */
  public static final String STATE_ERROR = 'ERROR';
  public static final String ACCESS_PERMISSION = 'SalesReport_Access';
  @TestVisible
  static final String SOURCE = 'SalesReportLinkPageController';
  /** Forms the LIFF app can open (?form=); anything else is ignored. */
  @TestVisible
  static final Set<String> FORMS = new Set<String>{ 'activity', 'opportunity' };

  public String state { get; private set; }
  public String lineDisplayName { get; private set; }
  public String userName { get; private set; }
  public String returnUrl { get; private set; }
  /** Request ID shown on unexpected errors, matching the Sales Report Log entry. */
  public String reference { get; private set; }
  private final String code;
  /** Why the page opened in a refused state, logged by logVisit(); null when there is nothing to log. */
  private String refusal;

  public SalesReportLinkPageController() {
    code = wellFormedCode(
      ApexPages.currentPage().getParameters().get('code')?.escapeHtml4()
    );
    userName = UserInfo.getName();
    String liffId = SalesReportSettingsService.liffId();
    returnUrl = liffId == null ? null : 'https://liff.line.me/' + liffId;
    // Back to the form the rep tapped in the rich menu before logging in (passed through the link by the LIFF app).
    String form = ApexPages.currentPage().getParameters().get('form');
    if (returnUrl != null && form != null && FORMS.contains(form)) {
      returnUrl += '?form=' + form;
    }

    if (!isAllowed()) {
      state = STATE_NOT_ALLOWED;
      return;
    }
    SalesReportLinkService service = new SalesReportLinkService();
    SalesReport_Link_Code__c usable = service.findUsableCode(code);
    if (usable == null) {
      state = STATE_INVALID;
      refusal =
        SalesReportException.LINK_CODE_INVALID +
        ': code ' +
        (code == null ? 'missing or malformed' : service.codeProblem(code));
      return;
    }
    lineDisplayName = usable.Line_Display_Name__c;
    String conflict = service.conflict(
      usable.Line_User_Id__c,
      UserInfo.getUserId()
    );
    if (conflict != null) {
      state = conflict == SalesReportException.ALREADY_LINKED
        ? STATE_ALREADY_LINKED
        : STATE_LINE_IN_USE;
      refusal = conflict + ': linking refused, existing link kept.';
      SalesReportLogService.setLineUserRef(usable.Line_User_Id__c);
      return;
    }
    state = STATE_CONFIRM;
  }

  /** True when the page opened refused and logVisit() still has to log why. */
  public Boolean hasRefusal {
    get {
      return refusal != null;
    }
  }

  /**
   * Logs why the page opened refused (expired, used or unknown code; already linked). Called by the page right after
   * it loads, as a CSRF-protected postback, because a page may not write records while loading. It only writes a log
   * entry, never a link or a code, and logs once.
   */
  public PageReference logVisit() {
    if (refusal != null) {
      SalesReportLogService.warn(SOURCE + '.open', refusal);
      SalesReportLogService.flush();
      refusal = null;
    }
    return null;
  }

  /** Links the rep, then goes straight back to the LIFF form (no "done" page in between) when the LIFF ID is set. */
  public PageReference confirm() {
    PageReference next = null;
    try {
      if (!isAllowed()) {
        state = STATE_NOT_ALLOWED;
        return null;
      }
      new SalesReportLinkService().consume(code, UserInfo.getUserId());
      state = STATE_DONE;
      SalesReportLogService.info(SOURCE + '.confirm', 'LINE account linked.');
      if (returnUrl != null) {
        next = new PageReference(returnUrl);
        next.setRedirect(true);
      }
    } catch (SalesReportException e) {
      state = e.code == SalesReportException.ALREADY_LINKED
        ? STATE_ALREADY_LINKED
        : e.code == SalesReportException.LINE_IN_USE
            ? STATE_LINE_IN_USE
            : STATE_INVALID;
      SalesReportLogService.warn(
        SOURCE + '.confirm',
        e.code + ': ' + e.getMessage()
      );
    } catch (Exception e) {
      state = STATE_ERROR;
      reference = Request.getCurrent().getRequestId();
      SalesReportLogService.error(SOURCE + '.confirm', e);
    } finally {
      SalesReportLogService.flush();
    }
    return next;
  }

  /** Codes are base64url (letters, digits, '-', '_'), so HTML-escaping never changes a valid one; anything else is dropped. Never rendered. */
  @TestVisible
  static String wellFormedCode(String raw) {
    if (raw == null || !Pattern.matches('[A-Za-z0-9_-]{20,100}', raw)) {
      return null;
    }
    return raw;
  }

  private static Boolean isAllowed() {
    return UserInfo.getUserType() == 'Standard' &&
      FeatureManagement.checkPermission(ACCESS_PERMISSION);
  }
}
