// Log Activity form (L5a). The fields come from GET /activity: the field set's fields this rep can create, with
// Salesforce's labels, picklist values, defaults and required flags (D-31). Required fields are checked here first
// for a quick answer; the server checks them again, and Salesforce's own errors (validation rules) come back as
// messages next to the fields they name. All text is rendered with textContent.
import { ApiError } from "./api.js";

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

const INPUT_TYPES = {
  text: "text",
  email: "email",
  phone: "tel",
  url: "url",
  date: "date",
  number: "number"
};

function buildControl(field, labels, id) {
  if (field.type === "textarea") {
    const area = el("textarea", "sr-input sr-textarea");
    area.rows = 4;
    if (field.maxLength) area.maxLength = field.maxLength;
    if (field.defaultValue != null) area.value = field.defaultValue;
    area.id = id;
    return { node: area, read: () => area.value.trim() };
  }
  if (field.type === "picklist") {
    const select = el("select", "sr-input sr-select");
    select.id = id;
    select.append(new Option(labels.selectPlaceholder || "", ""));
    (field.options || []).forEach((option) =>
      select.append(new Option(option.label, option.value))
    );
    if (field.defaultValue != null) select.value = field.defaultValue;
    return { node: select, read: () => select.value };
  }
  if (field.type === "multipicklist") {
    const group = el("div", "sr-choices");
    group.id = id;
    group.setAttribute("role", "group");
    const chosen = String(field.defaultValue || "").split(";");
    const boxes = (field.options || []).map((option) => {
      const label = el("label", "sr-choice");
      const box = document.createElement("input");
      box.type = "checkbox";
      box.value = option.value;
      box.checked = chosen.indexOf(option.value) !== -1;
      label.append(box, el("span", null, option.label));
      group.append(label);
      return box;
    });
    return {
      node: group,
      read: () => boxes.filter((box) => box.checked).map((box) => box.value)
    };
  }
  if (field.type === "boolean") {
    const box = document.createElement("input");
    box.type = "checkbox";
    box.className = "sr-checkbox";
    box.id = id;
    box.checked = field.defaultValue === true;
    return { node: box, read: () => box.checked };
  }
  const input = el("input", "sr-input");
  input.type = INPUT_TYPES[field.type] || "text";
  input.id = id;
  if (field.type === "number") {
    input.inputMode = "decimal";
    input.step = "any";
  }
  if (field.maxLength) input.maxLength = field.maxLength;
  if (field.defaultValue != null) input.value = field.defaultValue;
  return { node: input, read: () => input.value.trim() };
}

function isEmpty(value) {
  return (
    value === "" ||
    value === null ||
    value === undefined ||
    (Array.isArray(value) && value.length === 0)
  );
}

export function createActivityForm(options) {
  const api = options.api;
  const labels = options.labels;
  // The Account picker is created here so choosing an Account clears its error.
  const picker = options.createPicker(() => showError(accountError));
  const onSaved = options.onSaved;
  const onError = options.onError;

  const form = el("form", "sr-form");
  form.noValidate = true;
  const formError = el("p", "sr-error sr-form-error");
  formError.setAttribute("role", "alert");
  formError.hidden = true;
  const accountError = el("p", "sr-error");
  accountError.hidden = true;
  const fieldsBox = el("div", "sr-fields");
  fieldsBox.append(el("p", "sr-status", labels.loading || "…"));
  const save = el("button", "sr-button", labels.save);
  save.type = "submit";
  save.disabled = true;
  form.append(picker.element, accountError, fieldsBox, formError, save);

  const controls = [];

  function showError(box, message) {
    box.textContent = message || "";
    box.hidden = !message;
  }

  function clearErrors() {
    showError(formError);
    showError(accountError);
    controls.forEach((control) => {
      showError(control.error);
      control.wrapper.classList.remove("sr-invalid");
    });
  }

  function markField(name, message) {
    if (name === "accountId") {
      showError(accountError, message || labels.chooseAccount);
      return true;
    }
    const control = controls.find((item) => item.field.name === name);
    if (!control) return false;
    showError(control.error, message || labels.required);
    control.wrapper.classList.add("sr-invalid");
    return true;
  }

  function renderFields(definition) {
    fieldsBox.replaceChildren();
    (definition.fields || []).forEach((field, index) => {
      const id = "sr-field-" + index;
      const wrapper = el("div", "sr-field");
      const control = buildControl(field, labels, id);
      const label = el("label", "sr-label", field.label);
      label.htmlFor = id;
      if (field.required) {
        label.append(el("span", "sr-required", " *"));
        control.node.setAttribute("aria-required", "true");
      }
      const error = el("p", "sr-error");
      error.hidden = true;
      if (field.type === "boolean") {
        const row = el("label", "sr-choice");
        row.append(control.node, el("span", null, field.label));
        wrapper.append(row, error);
      } else {
        wrapper.append(label, control.node, error);
      }
      const clear = () => {
        showError(error);
        wrapper.classList.remove("sr-invalid");
      };
      wrapper.addEventListener("input", clear);
      wrapper.addEventListener("change", clear);
      fieldsBox.append(wrapper);
      controls.push({ field, wrapper, error, read: control.read });
    });
    save.disabled = false;
  }

  function collect() {
    const values = {};
    let valid = true;
    controls.forEach((control) => {
      const value = control.read();
      if (isEmpty(value)) {
        if (control.field.required) {
          markField(control.field.name);
          valid = false;
        }
        return;
      }
      values[control.field.name] = value;
    });
    return { values, valid };
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (save.disabled) return;
    clearErrors();
    const account = picker.selected();
    const collected = collect();
    if (!account) markField("accountId");
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
      onSaved(result, account);
    } catch (error) {
      save.disabled = false;
      save.textContent = labels.save;
      if (
        error instanceof ApiError &&
        (error.code === "INVALID_INPUT" || error.code === "SAVE_FAILED")
      ) {
        const unplaced = [];
        Object.keys(error.fields || {}).forEach((name) => {
          if (!markField(name, error.fields[name]))
            unplaced.push(error.fields[name]);
        });
        const message =
          error.code === "SAVE_FAILED" ? error.message : labels.checkFields;
        showError(formError, [message].concat(unplaced).join(" "));
        return;
      }
      onError(error);
    }
  });

  api
    .get("/activity")
    .then(renderFields)
    .catch((error) => onError(error));

  return { element: form };
}
