/**
 * Controller of the SalesReport_Liff Visualforce page (served by the Site to the guest user). Gives the LIFF app its
 * configuration: LIFF ID, the Apex REST base path (namespace-safe, packaging rule P6) and the UI labels (P11).
 */
public with sharing class SalesReportLiffPageController {
  @TestVisible
  static final String API_VERSION_PATH = 'salesreport/v1';

  /** JSON read by the LIFF app; rendered into an HTML attribute, so Visualforce HTML-encodes it. */
  public String configJson { get; private set; }

  public SalesReportLiffPageController() {
    configJson = JSON.serialize(
      new Map<String, Object>{
        'liffId' => SalesReportSettingsService.liffId(),
        'enabled' => SalesReportSettingsService.isEnabled(),
        'apiBase' => apiBase(),
        'labels' => labels()
      }
    );
  }

  @TestVisible
  static String apiBase() {
    String sitePrefix = Site.getPathPrefix();
    return (sitePrefix == null ? '' : sitePrefix) +
      '/services/apexrest/' +
      namespacePath() +
      API_VERSION_PATH;
  }

  /** "ns/" when the class runs inside a namespaced package, otherwise "". */
  @TestVisible
  static String namespacePath() {
    String className = SalesReportLiffPageController.class.getName();
    return className.contains('.') ? className.substringBefore('.') + '/' : '';
  }

  private static Map<String, String> labels() {
    return new Map<String, String>{
      'activityTitle' => System.Label.SalesReport_Activity_Title,
      'close' => System.Label.SalesReport_Close,
      'comingSoon' => System.Label.SalesReport_Coming_Soon,
      'errorGeneric' => System.Label.SalesReport_Error_Generic,
      'errorSessionExpired' => System.Label.SalesReport_Error_Session_Expired,
      'errorUnavailable' => System.Label.SalesReport_Error_Unavailable,
      'hello' => System.Label.SalesReport_Hello,
      'loading' => System.Label.SalesReport_Loading,
      'menuTitle' => System.Label.SalesReport_Menu_Title,
      'openInLine' => System.Label.SalesReport_Open_In_Line,
      'opportunityTitle' => System.Label.SalesReport_Opportunity_Title
    };
  }
}
