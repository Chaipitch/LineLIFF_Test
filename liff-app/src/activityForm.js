// Log Activity form (L5a). The fields come from GET /activity (shared rendering in formFields.js). Required fields are
// checked here first for a quick answer; the server checks them again, and Salesforce's own errors (validation rules)
// come back as messages next to the fields they name. Attachments (L5b) upload after the Task is saved.
import {
  createFieldList,
  el,
  format,
  showError,
  showSaveError,
  showRetryableError
} from "./formFields.js";
import { createAttachmentPicker, uploadFiles } from "./attachments.js";

export function createActivityForm(options) {
  const api = options.api;
  const labels = options.labels;
  // The Account picker is created here so choosing an Account clears its error and loads what it can link to.
  const picker = options.createPicker((chosen) => {
    showError(accountError);
    loadRelated(chosen);
  });
  const onSaved = options.onSaved;
  const attachments =
    options.attachments && options.attachments.maxFiles > 0
      ? createAttachmentPicker({ labels, limits: options.attachments })
      : null;
  const onError = options.onError;

  const form = el("form", "sr-form");
  form.noValidate = true;
  const formError = el("p", "sr-error sr-form-error");
  formError.setAttribute("role", "alert");
  formError.hidden = true;
  const accountError = el("p", "sr-error");
  accountError.hidden = true;
  const fields = createFieldList({
    labels,
    idPrefix: "sr-field-",
    dateDefaultToday: true
  });
  const save = el("button", "sr-button", labels.save);
  save.type = "submit";
  save.disabled = true;
  // Save stays at the bottom of the screen while the rep scrolls a long form; errors sit above it in the form.
  const actions = el("div", "sr-actions");
  actions.append(save);
  // "Related To" (one of the Account's Opportunities, or the Account itself) and "Name" (one of its Contacts), D-54.
  function selectField(id, labelText, emptyText) {
    const wrapper = el("div", "sr-field");
    const label = el("label", "sr-label", labelText);
    label.htmlFor = id;
    const select = el("select", "sr-input sr-select");
    select.id = id;
    const error = el("p", "sr-error");
    error.hidden = true;
    wrapper.append(label, select, error);
    select.addEventListener("change", () => showError(error));
    return {
      wrapper,
      select,
      error,
      fill(items) {
        select.replaceChildren(new Option(emptyText, ""));
        (items || []).forEach((item) =>
          select.append(
            new Option(
              item.detail ? item.name + " · " + item.detail : item.name,
              item.id
            )
          )
        );
      },
      value: () => select.value,
      text: () =>
        select.value ? select.options[select.selectedIndex].text : ""
    };
  }
  const relatedTo = selectField(
    "sr-related-to",
    labels.relatedToLabel,
    labels.relatedAccountOnly
  );
  const contact = selectField(
    "sr-contact",
    labels.contactLabel,
    labels.noneOption
  );
  const linkSection = el("div", "sr-link-fields");
  linkSection.hidden = true;
  linkSection.append(relatedTo.wrapper, contact.wrapper);
  let relatedToken = 0;

  async function loadRelated(account) {
    const token = ++relatedToken;
    relatedTo.fill([]);
    contact.fill([]);
    linkSection.hidden = !account;
    if (!account) return;
    try {
      const related = await api.get(
        "/activity?accountId=" + encodeURIComponent(account.id)
      );
      if (token !== relatedToken) return;
      relatedTo.fill(related.opportunities);
      contact.fill(related.contacts);
    } catch (error) {
      if (token === relatedToken) onError(error);
    }
  }

  form.append(picker.element, accountError, linkSection, fields.element);
  if (attachments) form.append(attachments.element);
  form.append(formError, actions);

  function markAccount(name, message) {
    if (name === "opportunityId") {
      showError(relatedTo.error, message);
      return true;
    }
    if (name === "contactId") {
      showError(contact.error, message);
      return true;
    }
    if (name !== "accountId") return false;
    showError(accountError, message || labels.chooseAccount);
    return true;
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (save.disabled) return;
    showError(formError);
    showError(accountError);
    showError(relatedTo.error);
    showError(contact.error);
    fields.clear();
    const account = picker.selected();
    const collected = fields.collect();
    if (!account) markAccount("accountId");
    if (!account || !collected.valid) {
      showError(formError, labels.checkFields);
      return;
    }
    save.disabled = true;
    save.textContent = labels.saving;
    try {
      const result = await api.post("/activity", {
        accountId: account.id,
        opportunityId: relatedTo.value() || null,
        contactId: contact.value() || null,
        values: collected.values
      });
      // What was saved, as the rep saw it, for the success screen.
      const summary = [
        { label: labels.accountLabel, value: account.name },
        {
          label: labels.relatedToLabel,
          value: relatedTo.text() || account.name
        },
        { label: labels.contactLabel, value: contact.text() }
      ].concat(fields.summary());
      // The Task exists from here on: upload problems are reported on the saved screen, never as a form error.
      const files = attachments ? attachments.files() : [];
      const failed = await uploadFiles(api, result.id, files, (done, total) => {
        save.textContent = format(labels.uploading, done, total);
      });
      onSaved(result, failed, summary);
    } catch (error) {
      save.disabled = false;
      save.textContent = labels.save;
      if (
        !showSaveError(error, labels, fields, markAccount, formError) &&
        !showRetryableError(error, labels, formError)
      )
        onError(error);
    }
  });

  api
    .get("/activity")
    .then((definition) => {
      fields.render(definition.fields);
      save.disabled = false;
    })
    .catch((error) => onError(error));

  return { element: form };
}
