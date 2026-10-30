/**
 * Attachments for Log Activity (L5b, D-34): one file per request, uploaded **as the rep** as a Salesforce File
 * published to the Task, so sharing and "Created By" are the rep's. Only the rep's own Task, only shortly after it
 * was logged, and only within the count / size / type limits from Sales Report Settings.
 */
public with sharing class SalesReportActivityFileService {
  /** Files can be added this long after the Task was created (the LIFF page uploads right after saving). */
  @TestVisible
  static final Integer ATTACH_WINDOW_MINUTES = 60;
  @TestVisible
  static final Integer MAX_NAME_LENGTH = 255;
  private static final Pattern TASK_ID = Pattern.compile(
    '00T[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?'
  );

  public SalesReportActivityFileData attach(
    SalesReportOrgApiCalloutService api,
    String taskId,
    String rawName,
    Blob data
  ) {
    if (taskId == null || !TASK_ID.matcher(taskId).matches()) {
      throw invalid('Missing or invalid activity ID.');
    }
    String name = cleanName(rawName);
    String extension = name.substringAfterLast('.').toLowerCase();
    if (!SalesReportSettingsService.attachmentFileTypes().contains(extension)) {
      throw invalid('This file type can\'t be attached.');
    }
    Integer maxBytes =
      SalesReportSettingsService.attachmentMaxSizeMb() *
      1024 *
      1024;
    if (data == null || data.size() == 0) {
      throw invalid('The file is empty.');
    }
    if (data.size() > maxBytes) {
      throw invalid(
        'The file is larger than ' +
          SalesReportSettingsService.attachmentMaxSizeMb() +
          ' MB.'
      );
    }

    checkOwnRecentTask(api, taskId);
    // taskId matched TASK_ID above, so it is safe to inline.
    Integer existing = api.query(
        'SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = \'' +
          taskId +
          '\''
      )
      .size();
    if (existing >= SalesReportSettingsService.attachmentMaxFiles()) {
      throw invalid(
        'You can attach up to ' +
          SalesReportSettingsService.attachmentMaxFiles() +
          ' files.'
      );
    }

    SalesReportActivityFileData result = new SalesReportActivityFileData();
    result.id = api.createFile(
      name.substringBeforeLast('.'),
      name,
      Id.valueOf(taskId),
      data
    );
    result.name = name;
    result.size = data.size();
    return result;
  }

  /** The Task through the rep's session: visible, created by the rep, and created within the attach window. */
  private static void checkOwnRecentTask(
    SalesReportOrgApiCalloutService api,
    String taskId
  ) {
    List<Object> records = api.query(
      'SELECT Id, CreatedById, CreatedDate FROM Task WHERE Id = \'' +
        taskId +
        '\' LIMIT 1'
    );
    Map<String, Object> task = records.isEmpty()
      ? null
      : (Map<String, Object>) records[0];
    if (
      task == null ||
      api.userId == null ||
      Id.valueOf((String) task.get('CreatedById')) != api.userId
    ) {
      throw SalesReportException.of(
        SalesReportException.NOT_AUTHORIZED,
        403,
        'Files can only be added to an activity you logged.'
      );
    }
    // The REST API returns GMT, e.g. 2026-10-30T05:33:45.000+0000.
    Datetime createdDate = Datetime.valueOfGmt(
      ((String) task.get('CreatedDate')).left(19).replace('T', ' ')
    );
    if (createdDate < Datetime.now().addMinutes(-ATTACH_WINDOW_MINUTES)) {
      throw invalid(
        'Files can only be added right after logging the activity.'
      );
    }
  }

  /** File name without any path, control characters or extra spaces; at most MAX_NAME_LENGTH characters. */
  @TestVisible
  static String cleanName(String rawName) {
    String name = rawName == null ? '' : rawName;
    Integer cut = Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\'));
    name = name.substring(cut + 1)
      .replaceAll('[\\p{Cntrl}]', '')
      .normalizeSpace();
    if (!name.contains('.') || name.startsWith('.')) {
      throw invalid('The file name needs an extension such as .jpg or .pdf.');
    }
    if (name.length() > MAX_NAME_LENGTH) {
      String extension = '.' + name.substringAfterLast('.');
      name = name.left(MAX_NAME_LENGTH - extension.length()) + extension;
    }
    return name;
  }

  private static SalesReportException invalid(String message) {
    return SalesReportException.of(
      SalesReportException.INVALID_INPUT,
      400,
      message
    );
  }
}
