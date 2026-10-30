// Same work against Platform Cache partition local.SalesReportCache (5-minute entries, remove = single use).
Cache.OrgPartition p = Cache.Org.getPartition('local.SalesReportCache');
List<String> keys = new List<String>();
Integer cpu0 = Limits.getCpuTime(); Long t0 = System.currentTimeMillis();
for (Integer i = 0; i < 20; i++) {
  String code = EncodingUtil.base64Encode(Crypto.generateAesKey(256));
  String key = 'lc' + EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(code))).left(40);
  p.put(key, new Map<String, String>{ 'sub' => 'Ubenchmark', 'name' => 'Benchmark' }, 300);
  keys.add(key);
}
Long t1 = System.currentTimeMillis(); Integer cpu1 = Limits.getCpuTime();
Integer found = 0;
for (String k : keys) { if (p.get(k) != null) found++; }
Long t2 = System.currentTimeMillis(); Integer cpu2 = Limits.getCpuTime();
Integer removed = 0;
for (String k : keys) { if (p.remove(k)) removed++; }
Long t3 = System.currentTimeMillis(); Integer cpu3 = Limits.getCpuTime();
System.debug('BENCH cache create20Ms=' + (t1 - t0) + ' cpu=' + (cpu1 - cpu0) + ' lookup20Ms=' + (t2 - t1) + ' cpu=' + (cpu2 - cpu1) + ' found=' + found + ' removeMs=' + (t3 - t2) + ' removed=' + removed + ' capacityKB=' + p.getCapacity() + ' dml=' + Limits.getDmlStatements() + ' soql=' + Limits.getQueries());
