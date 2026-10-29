/**
 * Account auto-complete rules (L4). The query runs through the org REST API **as the rep**, so only Accounts the rep
 * can see are returned and fields the rep can't read fail the query instead of leaking. Searched fields are Name
 * plus the text fields of field set SalesReport_Account_Search (packaging rule P3: no static references to org
 * fields). Name matches that start with the term come first.
 */
public with sharing class SalesReportAccountService {
  public static final String SEARCH_FIELD_SET = 'SalesReport_Account_Search';
  @TestVisible
  static final Integer MAX_TERM_LENGTH = 80;
  /** Fetched before ranking, so prefix matches aren't cut off by alphabetical order. */
  private static final Integer FETCH_LIMIT = 50;
  private static final Set<Schema.DisplayType> SEARCHABLE_TYPES = new Set<Schema.DisplayType>{
    Schema.DisplayType.STRING,
    Schema.DisplayType.EMAIL,
    Schema.DisplayType.PHONE,
    Schema.DisplayType.URL
  };

  public SalesReportAccountData search(
    SalesReportOrgApiCalloutService api,
    String rawTerm
  ) {
    String term = normalised(rawTerm);
    if (term.length() < SalesReportSettingsService.accountSearchMinChars()) {
      throw SalesReportException.of(
        SalesReportException.QUERY_TOO_SHORT,
        400,
        'Type at least ' +
          SalesReportSettingsService.accountSearchMinChars() +
          ' characters.'
      );
    }
    List<String> extraFields = extraSearchFields();
    List<Object> records = api.query(soql(term, extraFields));
    return ranked(records, term, extraFields);
  }

  @TestVisible
  static String normalised(String rawTerm) {
    String term = rawTerm == null ? '' : rawTerm.normalizeSpace();
    return term.left(MAX_TERM_LENGTH);
  }

  /** Text fields of the field set other than Name, as API names (namespace-correct via describe). */
  @TestVisible
  static List<String> extraSearchFields() {
    List<String> fields = new List<String>();
    Schema.FieldSet fieldSet = Schema.SObjectType.Account.fieldSets.getMap()
      .get(SEARCH_FIELD_SET);
    if (fieldSet == null) {
      return fields;
    }
    for (Schema.FieldSetMember member : fieldSet.getFields()) {
      String path = member.getFieldPath();
      if (
        path != 'Name' &&
        !path.contains('.') &&
        SEARCHABLE_TYPES.contains(member.getType())
      ) {
        fields.add(path);
      }
    }
    return fields;
  }

  /** LIKE '%term%' on every search field; escapeSingleQuotes escapes quotes and backslashes, then LIKE wildcards. */
  @TestVisible
  static String soql(String term, List<String> extraFields) {
    String pattern =
      '\'%' +
      String.escapeSingleQuotes(term).replace('%', '\\%').replace('_', '\\_') +
      '%\'';
    List<String> selectFields = new List<String>{ 'Id', 'Name' };
    selectFields.addAll(extraFields);
    List<String> conditions = new List<String>{ 'Name LIKE ' + pattern };
    for (String field : extraFields) {
      conditions.add(field + ' LIKE ' + pattern);
    }
    return 'SELECT ' +
      String.join(selectFields, ', ') +
      ' FROM Account WHERE ' +
      String.join(conditions, ' OR ') +
      ' ORDER BY Name LIMIT ' +
      FETCH_LIMIT;
  }

  @TestVisible
  static SalesReportAccountData ranked(
    List<Object> records,
    String term,
    List<String> extraFields
  ) {
    String needle = term.toLowerCase();
    List<SalesReportAccountData.Item> starts = new List<SalesReportAccountData.Item>();
    List<SalesReportAccountData.Item> others = new List<SalesReportAccountData.Item>();
    for (Object row : records) {
      Map<String, Object> record = (Map<String, Object>) row;
      SalesReportAccountData.Item item = new SalesReportAccountData.Item();
      item.id = (String) record.get('Id');
      item.name = (String) record.get('Name');
      for (String field : extraFields) {
        Object value = record.get(field);
        if (value != null && String.isNotBlank(String.valueOf(value))) {
          item.detail = String.valueOf(value);
          break;
        }
      }
      if (item.name != null && item.name.toLowerCase().startsWith(needle)) {
        starts.add(item);
      } else {
        others.add(item);
      }
    }
    SalesReportAccountData data = new SalesReportAccountData();
    Integer max = SalesReportSettingsService.accountSearchMaxResults();
    for (
      List<SalesReportAccountData.Item> bucket : new List<List<SalesReportAccountData.Item>>{
        starts,
        others
      }
    ) {
      for (SalesReportAccountData.Item item : bucket) {
        if (data.accounts.size() == max) {
          return data;
        }
        data.accounts.add(item);
      }
    }
    return data;
  }
}
