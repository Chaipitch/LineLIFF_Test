// Schedules the nightly Sales Report cleanup (02:00 in the running user's time zone). Run once per org:
//   sf apex run -o <alias> -f scripts/apex/schedule-cleanup.apex
// Re-running fails with "already scheduled"; unschedule it in Setup → Scheduled Jobs first.
System.debug('SCHEDULED ' + SalesReportCleanupService.schedule());
System.debug('DRYRUN ' + JSON.serialize(new SalesReportCleanupService().run()));
