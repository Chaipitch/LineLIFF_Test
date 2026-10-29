/**
 * Namespace-safe names and paths (packaging rule P6). Empty strings while unpackaged.
 */
public with sharing class SalesReportNamespaceService {
  /** "ns" inside a namespaced package, otherwise "". */
  public static String namespace() {
    String className = SalesReportNamespaceService.class.getName();
    return className.contains('.') ? className.substringBefore('.') : '';
  }

  /** "ns/" for Apex REST paths, otherwise "". */
  public static String restPathPrefix() {
    String ns = namespace();
    return ns == '' ? '' : ns + '/';
  }

  /** Path of a Visualforce page on the org's own domain, e.g. "/apex/SalesReport_Link". */
  public static String pagePath(String pageName) {
    String ns = namespace();
    return '/apex/' + (ns == '' ? '' : ns + '__') + pageName;
  }
}
