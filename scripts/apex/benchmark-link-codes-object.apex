// Link codes in the SalesReport_Link_Code__c object: create 20 codes, look each up, mark it used, then clean up.
SalesReportLineVerifyData d = new SalesReportLineVerifyData();
d.sub = 'Ubenchmark000000000000000000000000'; d.name = 'Benchmark';
SalesReportLinkService svc = new SalesReportLinkService();
List<String> codes = new List<String>();
Integer cpu0 = Limits.getCpuTime(); Long t0 = System.currentTimeMillis(); Integer dml0 = Limits.getDmlStatements();
for (Integer i = 0; i < 20; i++) codes.add(svc.createCode(d));
Long t1 = System.currentTimeMillis(); Integer cpu1 = Limits.getCpuTime();
Integer found = 0;
for (String c : codes) { if (svc.findUsableCode(c) != null) found++; }
Long t2 = System.currentTimeMillis(); Integer cpu2 = Limits.getCpuTime();
List<SalesReport_Link_Code__c> rows = [SELECT Id FROM SalesReport_Link_Code__c WHERE Line_User_Id__c = :d.sub];
for (SalesReport_Link_Code__c r : rows) r.Used_At__c = Datetime.now();
update rows;
Long t3 = System.currentTimeMillis(); Integer cpu3 = Limits.getCpuTime();
System.debug('BENCH object create20Ms=' + (t1 - t0) + ' cpu=' + (cpu1 - cpu0) + ' lookup20Ms=' + (t2 - t1) + ' cpu=' + (cpu2 - cpu1) + ' found=' + found + ' markUsedMs=' + (t3 - t2) + ' dml=' + (Limits.getDmlStatements() - dml0) + ' soql=' + Limits.getQueries());
delete rows;
System.debug('BENCH object cleaned=' + rows.size());
