/** Keeps the active keys and the audit fields of Sales Report LINE Links consistent (D-44). Logic in the handler. */
trigger SalesReportLineLinkTrigger on SalesReport_Line_Link__c(
  before insert,
  before update
) {
  SalesReportLineLinkTriggerHandler.beforeSave(Trigger.new, Trigger.oldMap);
}
