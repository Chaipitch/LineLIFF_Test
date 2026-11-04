// Update Opportunity form (L5c). Choose an Account → its open Opportunities (GET /opportunities?accountId=) → the
// update form filled with the current values (GET /opportunities?id=, fields from field set
// SalesReport_Opportunity_Form) → Save (POST /opportunities). Empty optional fields are sent so Salesforce clears them.
// Stage choices are open stages only; closing a deal is done in Salesforce. All text uses textContent.
import {
  createFieldList,
  el,
  formatDate,
  showError,
  showRetryableError,
  showSaveError
} from "./formFields.js";

export function createOpportunityForm(options) {
  const api = options.api;
  const labels = options.labels;
  const onSaved = options.onSaved;
  const onError = options.onError;
  let account = null;
  let opportunity = null;
  let loadToken = 0;

  const form = el("form", "sr-form");
  form.noValidate = true;
  const picker = options.createPicker((chosen) => {
    showError(accountError);
    account = chosen;
    chooseOpportunity(null);
    if (chosen) loadOpportunities(chosen);
    else oppSection.hidden = true;
  });
  const accountError = el("p", "sr-error");
  accountError.hidden = true;

  // Opportunity choice: list of the Account's open Opportunities, or the chosen one with "Change".
  const oppSection = el("div", "sr-field");
  oppSection.hidden = true;
  const oppLabel = el("p", "sr-label", labels.opportunityLabel);
  const oppStatus = el("p", "sr-hint");
  oppStatus.setAttribute("aria-live", "polite");
  const oppList = el("ul", "sr-options");
  oppList.setAttribute("role", "listbox");
  const oppChosen = el("div", "sr-chosen");
  oppChosen.hidden = true;
  const oppError = el("p", "sr-error");
  oppError.hidden = true;
  oppSection.append(oppLabel, oppStatus, oppList, oppChosen, oppError);

  const fields = createFieldList({
    labels,
    idPrefix: "sr-opp-field-",
    sendEmpty: true,
    minChars: options.minChars,
    onError,
    // Lookup fields (e.g. Main PreSales Engineer): records the rep can see, searched through the same endpoint.
    searchLookup: async (field, term, signal) =>
      (
        await api.get(
          "/opportunities?lookup=" +
            encodeURIComponent(field.name) +
            "&q=" +
            encodeURIComponent(term),
          { signal }
        )
      ).records
  });
  fields.element.hidden = true;
  const formError = el("p", "sr-error sr-form-error");
  formError.setAttribute("role", "alert");
  formError.hidden = true;
  const save = el("button", "sr-button", labels.save);
  save.type = "submit";
  save.disabled = true;
  const actions = el("div", "sr-actions");
  actions.append(save);
  form.append(
    picker.element,
    accountError,
    oppSection,
    fields.element,
    formError,
    actions
  );

  function markExtra(name, message) {
    if (name === "accountId") {
      showError(accountError, message || labels.chooseAccount);
      return true;
    }
    if (name === "opportunityId") {
      showError(oppError, message || labels.chooseOpportunity);
      return true;
    }
    return false;
  }

  async function loadOpportunities(chosenAccount) {
    const token = ++loadToken;
    oppSection.hidden = false;
    oppList.replaceChildren();
    oppStatus.textContent = labels.loading;
    try {
      const result = await api.get(
        "/opportunities?accountId=" + encodeURIComponent(chosenAccount.id)
      );
      if (token !== loadToken) return;
      const items = result.opportunities || [];
      oppStatus.textContent = items.length ? "" : labels.noOpenOpportunities;
      oppList.replaceChildren(
        ...items.map((item) => {
          const li = el("li");
          const option = el("button", "sr-option");
          option.type = "button";
          option.setAttribute("role", "option");
          option.append(el("span", "sr-option-name", item.name));
          const detail = [item.stage, formatDate(item.closeDate)]
            .filter(Boolean)
            .join(" · ");
          if (detail) option.append(el("span", "sr-option-detail", detail));
          option.addEventListener("click", () => chooseOpportunity(item));
          li.append(option);
          return li;
        })
      );
    } catch (error) {
      if (token === loadToken) {
        oppStatus.textContent = "";
        onError(error);
      }
    }
  }

  function chooseOpportunity(item) {
    opportunity = item;
    showError(oppError);
    showError(formError);
    fields.element.hidden = true;
    save.disabled = true;
    if (!item) {
      oppChosen.hidden = true;
      oppList.hidden = false;
      return;
    }
    oppList.hidden = true;
    oppStatus.textContent = "";
    const name = el("span", "sr-chosen-name", item.name);
    const change = el("button", "sr-link", labels.change);
    change.type = "button";
    change.addEventListener("click", () => chooseOpportunity(null));
    oppChosen.replaceChildren(name, change);
    oppChosen.hidden = false;
    loadForm(item);
  }

  async function loadForm(item) {
    const token = ++loadToken;
    fields.element.hidden = false;
    fields.render([]);
    fields.element.replaceChildren(el("p", "sr-hint", labels.loading));
    try {
      const definition = await api.get(
        "/opportunities?id=" + encodeURIComponent(item.id)
      );
      if (token !== loadToken) return;
      fields.render(definition.fields);
      save.disabled = false;
    } catch (error) {
      if (token !== loadToken) return;
      if (!showSaveError(error, labels, fields, markExtra, formError))
        onError(error);
    }
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (save.disabled) return;
    showError(formError);
    showError(accountError);
    showError(oppError);
    fields.clear();
    if (!account) markExtra("accountId");
    if (!opportunity) markExtra("opportunityId");
    const collected = fields.collect();
    if (!account || !opportunity || !collected.valid) {
      showError(formError, labels.checkFields);
      return;
    }
    save.disabled = true;
    save.textContent = labels.saving;
    try {
      const result = await api.post("/opportunities", {
        id: opportunity.id,
        accountId: account.id,
        values: collected.values
      });
      // What was saved, as the rep saw it, for the success screen.
      onSaved(
        result,
        [
          { label: labels.accountLabel, value: account.name },
          { label: labels.opportunityLabel, value: opportunity.name }
        ].concat(fields.summary())
      );
    } catch (error) {
      save.disabled = false;
      save.textContent = labels.save;
      if (
        !showSaveError(error, labels, fields, markExtra, formError) &&
        !showRetryableError(error, labels, formError)
      )
        onError(error);
    }
  });

  return { element: form };
}
