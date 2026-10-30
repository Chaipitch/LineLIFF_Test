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
        'accountSearch' => new Map<String, Object>{
          'minChars' => SalesReportSettingsService.accountSearchMinChars(),
          'maxResults' => SalesReportSettingsService.accountSearchMaxResults()
        },
        'attachments' => new Map<String, Object>{
          'maxFiles' => SalesReportSettingsService.attachmentMaxFiles(),
          'maxSizeMb' => SalesReportSettingsService.attachmentMaxSizeMb(),
          'types' => SalesReportSettingsService.attachmentFileTypes()
        },
        'labels' => labels()
      }
    );
  }

  @TestVisible
  static String apiBase() {
    String sitePrefix = Site.getPathPrefix();
    return (sitePrefix == null ? '' : sitePrefix) +
      '/services/apexrest/' +
      SalesReportNamespaceService.restPathPrefix() +
      API_VERSION_PATH;
  }

  private static Map<String, String> labels() {
    return new Map<String, String>{
      'accountLabel' => System.Label.SalesReport_Account_Label,
      'accountPlaceholder' => System.Label.SalesReport_Account_Search_Placeholder,
      'accountNoResults' => System.Label.SalesReport_No_Results,
      'accountSearching' => System.Label.SalesReport_Searching,
      'change' => System.Label.SalesReport_Change,
      'activityTitle' => System.Label.SalesReport_Activity_Title,
      'activitySaved' => System.Label.SalesReport_Activity_Saved,
      'attachmentsLabel' => System.Label.SalesReport_Attachments_Label,
      'addFile' => System.Label.SalesReport_Add_File,
      'removeFile' => System.Label.SalesReport_Remove_File,
      'fileTooLarge' => System.Label.SalesReport_File_Too_Large,
      'fileTypeNotAllowed' => System.Label.SalesReport_File_Type_Not_Allowed,
      'maxFiles' => System.Label.SalesReport_Max_Files,
      'uploading' => System.Label.SalesReport_Uploading,
      'uploadFailed' => System.Label.SalesReport_Upload_Failed,
      'retry' => System.Label.SalesReport_Retry,
      'checkFields' => System.Label.SalesReport_Check_Fields,
      'chooseAccount' => System.Label.SalesReport_Choose_Account,
      'logAnother' => System.Label.SalesReport_Log_Another,
      'required' => System.Label.SalesReport_Required,
      'save' => System.Label.SalesReport_Save,
      'saving' => System.Label.SalesReport_Saving,
      'selectPlaceholder' => System.Label.SalesReport_Select_Placeholder,
      'connectBody' => System.Label.SalesReport_Connect_Body,
      'connectButton' => System.Label.SalesReport_Connect_Button,
      'connectCheck' => System.Label.SalesReport_Connect_Check,
      'connectTitle' => System.Label.SalesReport_Connect_Title,
      'connectWaiting' => System.Label.SalesReport_Connect_Waiting,
      'errorNotAuthorized' => System.Label.SalesReport_Error_Not_Authorized,
      'linkedAs' => System.Label.SalesReport_Linked_As,
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
