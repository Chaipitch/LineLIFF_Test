// Log Activity form (L5a). The fields come from GET /activity (shared rendering in formFields.js). Required fields are
// checked here first for a quick answer; the server checks them again, and Salesforce's own errors (validation rules)
// come back as messages next to the fields they name. Attachments (L5b) upload after the Task is saved.
import {
  createFieldList,
  el,
  format,
  showError,
  showSaveError
} from "./formFields.js";
import { createAttachmentPicker, uploadFiles } from "./attachments.js";

export function createActivityForm(options) {
  const api = options.api;
  const labels = options.labels;
  // The Account picker is created here so choosing an Account clears its error.
  const picker = options.createPicker(() => showError(accountError));
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
  form.append(picker.element, accountError, fields.element);
  if (attachments) form.append(attachments.element);
  form.append(formError, actions);

  function markAccount(name, message) {
    if (name !== "accountId") return false;
    showError(accountError, message || labels.chooseAccount);
    return true;
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (save.disabled) return;
    showError(formError);
    showError(accountError);
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
        values: collected.values
      });
      // The Task exists from here on: upload problems are reported on the saved screen, never as a form error.
      const files = attachments ? attachments.files() : [];
      const failed = await uploadFiles(api, result.id, files, (done, total) => {
        save.textContent = format(labels.uploading, done, total);
      });
      onSaved(result, failed);
    } catch (error) {
      save.disabled = false;
      save.textContent = labels.save;
      if (!showSaveError(error, labels, fields, markAccount, formError))
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
