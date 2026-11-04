/**
 * Update Opportunity (L5c): the Account's open Opportunities, the update form and the update, all **as the rep**
 * (Option B), so only Opportunities the rep can see and fields the rep can edit are offered.
 *
 * The form comes from field set SalesReport_Opportunity_Form through SalesReportFormService (D-21, D-31), filled with
 * the record's current values. Stage choices are the active open stages (closing is done in Salesforce — validation
 * rules need contract / reason fields, Q-O3). The Opportunity must
 * be open and belong to the Account chosen on the form.
 */
public with sharing class SalesReportOpportunityService {
  public static final String FORM_FIELD_SET = 'SalesReport_Opportunity_Form';
  @TestVisible
  static final Integer MAX_LIST = 50;
  private static final String OPPORTUNITY_OBJECT = 'Opportunity';
  private static final String STAGE_FIELD = 'StageName';
  private static final Pattern ACCOUNT_ID = Pattern.compile(
    '001[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?'
  );
  private static final Pattern OPPORTUNITY_ID = Pattern.compile(
    '006[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?'
  );

  public SalesReportOpportunityData listOpen(
    SalesReportOrgApiCalloutService api,
    String accountId
  ) {
    if (accountId == null || !ACCOUNT_ID.matcher(accountId).matches()) {
      throw invalid('Choose an Account.', 'accountId');
    }
    // accountId matched ACCOUNT_ID above, so it is safe to inline.
    List<Object> records = api.query(
      'SELECT Id, Name, toLabel(StageName), CloseDate, Owner.Name FROM Opportunity WHERE AccountId = \'' +
        accountId +
        '\' AND IsClosed = false ORDER BY CloseDate ASC NULLS LAST LIMIT ' +
        MAX_LIST
    );
    SalesReportOpportunityData data = new SalesReportOpportunityData();
    for (Object row : records) {
      Map<String, Object> record = (Map<String, Object>) row;
      SalesReportOpportunityData.Item item = new SalesReportOpportunityData.Item();
      item.id = (String) record.get('Id');
      item.name = (String) record.get('Name');
      item.stage = (String) record.get(STAGE_FIELD);
      item.closeDate = (String) record.get('CloseDate');
      Map<String, Object> owner = (Map<String, Object>) record.get('Owner');
      item.ownerName = owner == null ? null : (String) owner.get('Name');
      data.opportunities.add(item);
    }
    return data;
  }

  public SalesReportOpportunityFormData form(
    SalesReportOrgApiCalloutService api,
    String opportunityId
  ) {
    checkId(opportunityId);
    SalesReportFormService context = formService(api);
    Set<String> extraFields = new Set<String>(context.byName.keySet());
    // Lookups also read the related record's name, e.g. PreSales_Engineer__r.Name (names from the UI API).
    for (String relationship : context.lookupRelationships.values()) {
      extraFields.add(relationship + '.Name');
    }
    Map<String, Object> current = openOpportunity(
      api,
      opportunityId,
      extraFields
    );
    restrictStages(context, (String) current.get(STAGE_FIELD));
    for (SalesReportFormData.Field field : context.form.fields) {
      field.defaultValue = current.get(field.name);
      String relationship = context.lookupRelationships.get(field.name);
      if (relationship != null && current.get(relationship) != null) {
        field.displayValue = (String) ((Map<String, Object>) current.get(
            relationship
          ))
          .get('Name');
      }
    }
    SalesReportOpportunityFormData data = summary(current);
    data.fields = context.form.fields;
    return data;
  }

  /** Records for a lookup field of the form (e.g. Main PreSales Engineer), searched as the rep. */
  public SalesReportLookupData searchLookup(
    SalesReportOrgApiCalloutService api,
    String fieldName,
    String term
  ) {
    return SalesReportFormService.searchLookup(
      api,
      Opportunity.SObjectType,
      FORM_FIELD_SET,
      fieldName,
      term
    );
  }

  public SalesReportOpportunityFormData save(
    SalesReportOrgApiCalloutService api,
    String body
  ) {
    Map<String, Object> input = SalesReportFormService.parseBody(body);
    Map<String, Object> submitted = SalesReportFormService.valuesOf(
      input.get('values')
    );
    String opportunityId = SalesReportFormService.stringOf(input, 'id');
    String accountId = SalesReportFormService.stringOf(input, 'accountId');
    checkId(opportunityId);
    if (accountId == null || !ACCOUNT_ID.matcher(accountId).matches()) {
      throw invalid('Choose an Account.', 'accountId');
    }

    Map<String, Object> current = openOpportunity(api, opportunityId, null);
    if (
      Id.valueOf((String) current.get('AccountId')) != Id.valueOf(accountId)
    ) {
      throw invalid(
        'This opportunity does not belong to the chosen Account.',
        'opportunityId'
      );
    }
    SalesReportFormService context = formService(api);
    restrictStages(context, (String) current.get(STAGE_FIELD));
    Map<String, String> errors = new Map<String, String>();
    Map<String, Object> changes = context.values(submitted, errors);
    if (!errors.isEmpty()) {
      throw SalesReportException.withFields(
        SalesReportException.INVALID_INPUT,
        400,
        'Please check the highlighted fields.',
        errors
      );
    }
    if (!changes.isEmpty()) {
      api.updateRecord(OPPORTUNITY_OBJECT, Id.valueOf(opportunityId), changes);
    }
    return summary(current);
  }

  private static SalesReportFormService formService(
    SalesReportOrgApiCalloutService api
  ) {
    return new SalesReportFormService(
      api,
      Opportunity.SObjectType,
      FORM_FIELD_SET,
      SalesReportFormService.Purpose.EDIT_RECORD,
      true
    );
  }

  /** Stage choices: open (and allowed) stages, plus the Opportunity's current stage so it still shows and saves. */
  private static void restrictStages(
    SalesReportFormService context,
    String currentStage
  ) {
    Set<String> stages = allowedStages();
    if (currentStage != null) {
      stages.add(currentStage);
    }
    context.restrictOptions(STAGE_FIELD, stages);
    // An old (inactive) stage is not in the picklist values; keep it so an unchanged stage can still be saved.
    context.keepOption(STAGE_FIELD, currentStage);
  }

  /** Active open stages (closing a deal is done in Salesforce). */
  @TestVisible
  static Set<String> allowedStages() {
    Set<String> stages = new Set<String>();
    for (OpportunityStage stage : [
      SELECT ApiName
      FROM OpportunityStage
      WHERE IsActive = TRUE AND IsClosed = FALSE
      WITH SYSTEM_MODE
    ]) {
      stages.add(stage.ApiName);
    }
    return stages;
  }

  /**
   * The Opportunity through the rep's session (visible to them), with the extra fields; refuses closed ones. Field
   * names come from the field set via describe, so they are safe to inline.
   */
  private static Map<String, Object> openOpportunity(
    SalesReportOrgApiCalloutService api,
    String opportunityId,
    Set<String> extraFields
  ) {
    Set<String> fields = new Set<String>{
      'Id',
      'Name',
      'AccountId',
      'IsClosed',
      STAGE_FIELD
    };
    if (extraFields != null) {
      fields.addAll(extraFields);
    }
    // opportunityId matched OPPORTUNITY_ID, so it is safe to inline.
    List<Object> records = api.query(
      'SELECT ' +
        String.join(new List<String>(fields), ', ') +
        ' FROM Opportunity WHERE Id = \'' +
        opportunityId +
        '\' LIMIT 1'
    );
    if (records.isEmpty()) {
      throw invalid(
        'This opportunity was not found or you cannot see it.',
        'opportunityId'
      );
    }
    Map<String, Object> record = (Map<String, Object>) records[0];
    if (record.get('IsClosed') == true) {
      throw invalid(
        'This opportunity is closed; update it in Salesforce.',
        'opportunityId'
      );
    }
    return record;
  }

  private static SalesReportOpportunityFormData summary(
    Map<String, Object> record
  ) {
    SalesReportOpportunityFormData data = new SalesReportOpportunityFormData();
    data.id = (String) record.get('Id');
    data.name = (String) record.get('Name');
    data.accountId = (String) record.get('AccountId');
    return data;
  }

  private static void checkId(String opportunityId) {
    if (
      opportunityId == null || !OPPORTUNITY_ID.matcher(opportunityId).matches()
    ) {
      throw invalid('Choose an opportunity.', 'opportunityId');
    }
  }

  private static SalesReportException invalid(String message, String field) {
    return SalesReportException.withFields(
      SalesReportException.INVALID_INPUT,
      400,
      message,
      new Map<String, String>{ field => message }
    );
  }
}
