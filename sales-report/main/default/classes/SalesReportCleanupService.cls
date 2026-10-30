/**
 * Nightly housekeeping (L7), scheduled with schedule(): deletes one-time link codes a day after they expired, logs
 * older than Log Retention (days), and rate-limit counters older than a day. Up to MAX_ROWS rows of each kind per run;
 * anything left over goes the next night.
 *
 * `without sharing` with explicit SYSTEM_MODE (DATA-DICTIONARY §5.3): these rows are owned by the Site guest / default
 * record owner and must be removed whoever runs the job.
 */
public without sharing class SalesReportCleanupService implements Schedulable {
  public static final String JOB_NAME = 'Sales Report cleanup';
  /** Every day at 02:00 in the time zone of the user who schedules it. */
  public static final String CRON = '0 0 2 * * ?';
  @TestVisible
  static final Integer MAX_ROWS = 3000;
  private static final String SOURCE = 'SalesReportCleanupService';

  public static String schedule() {
    return System.schedule(JOB_NAME, CRON, new SalesReportCleanupService());
  }

  public void execute(SchedulableContext context) {
    run();
  }

  /** Returns the number of rows deleted per kind. */
  public Map<String, Integer> run() {
    Datetime dayAgo = Datetime.now().addDays(-1);
    Datetime logCutoff = Datetime.now()
      .addDays(-SalesReportSettingsService.logRetentionDays());
    Map<String, Integer> deleted = new Map<String, Integer>{
      'linkCodes' => remove(
        [
          SELECT Id
          FROM SalesReport_Link_Code__c
          WHERE Expires_At__c < :dayAgo
          WITH SYSTEM_MODE
          LIMIT :MAX_ROWS
        ]
      ),
      'logs' => remove(
        [
          SELECT Id
          FROM SalesReport_Log__c
          WHERE CreatedDate < :logCutoff
          WITH SYSTEM_MODE
          LIMIT :MAX_ROWS
        ]
      ),
      'rateLimits' => remove(
        [
          SELECT Id
          FROM SalesReport_Rate_Limit__c
          WHERE Window_Start__c < :dayAgo
          WITH SYSTEM_MODE
          LIMIT :MAX_ROWS
        ]
      )
    };
    SalesReportLogService.info(SOURCE, 'Deleted ' + JSON.serialize(deleted));
    SalesReportLogService.flush();
    return deleted;
  }

  private static Integer remove(List<SObject> rows) {
    if (rows.isEmpty()) {
      return 0;
    }
    List<Id> deletedIds = new List<Id>();
    for (
      Database.DeleteResult result : Database.delete(
        rows,
        false,
        AccessLevel.SYSTEM_MODE
      )
    ) {
      if (result.isSuccess()) {
        deletedIds.add(result.getId());
      }
    }
    // Temporary rows: keep them out of the Recycle Bin (it counts against data storage for 15 days).
    if (!deletedIds.isEmpty()) {
      Database.emptyRecycleBin(deletedIds);
    }
    return deletedIds.size();
  }
}
