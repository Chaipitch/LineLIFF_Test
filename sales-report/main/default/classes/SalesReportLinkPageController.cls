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
  public static final String ACCESS_PERMISSION = 'SalesReport_Access';
  @TestVisible
  static final String SOURCE = 'SalesReportLinkPageController';

  public String state { get; private set; }
  public String lineDisplayName { get; private set; }
  public String userName { get; private set; }
  public String returnUrl { get; private set; }
  private final String code;

  public SalesReportLinkPageController() {
    code = wellFormedCode(
      ApexPages.currentPage().getParameters().get('code')?.escapeHtml4()
    );
    userName = UserInfo.getName();
    String liffId = SalesReportSettingsService.liffId();
    returnUrl = liffId == null ? null : 'https://liff.line.me/' + liffId;

    if (!isAllowed()) {
      state = STATE_NOT_ALLOWED;
      return;
    }
    SalesReport_Link_Code__c usable = new SalesReportLinkService()
      .findUsableCode(code);
    if (usable == null) {
      state = STATE_INVALID;
      return;
    }
    lineDisplayName = usable.Line_Display_Name__c;
    state = STATE_CONFIRM;
  }

  public PageReference confirm() {
    try {
      if (!isAllowed()) {
        state = STATE_NOT_ALLOWED;
        return null;
      }
      new SalesReportLinkService().consume(code, UserInfo.getUserId());
      state = STATE_DONE;
      SalesReportLogService.info(SOURCE + '.confirm', 'LINE account linked.');
    } catch (SalesReportException e) {
      state = STATE_INVALID;
      SalesReportLogService.warn(
        SOURCE + '.confirm',
        e.code + ': ' + e.getMessage()
      );
    } catch (Exception e) {
      state = STATE_INVALID;
      SalesReportLogService.error(SOURCE + '.confirm', e);
    } finally {
      SalesReportLogService.flush();
    }
    return null;
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
