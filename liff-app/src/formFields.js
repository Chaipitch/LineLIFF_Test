// Fields of a LINE form, built from the server's form definition (SalesReportFormData): Salesforce labels, input types,
// picklist values, defaults or current values, and required flags (D-31). Shared by Log Activity and Update
// Opportunity. Errors are shown next to each field and cleared as soon as the rep changes it. All text uses textContent.
import { ApiError } from "./api.js";

export function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

export function format(template, ...values) {
  return String(template || "").replace(/\{(\d+)\}/g, (match, i) =>
    values[i] !== undefined ? values[i] : match
  );
}

export function showError(box, message) {
  box.textContent = message || "";
  box.hidden = !message;
  // The form-level error sits at the end of a long form: bring it into view so the rep sees why nothing was saved.
  if (message && box.classList.contains("sr-form-error") && box.scrollIntoView)
    box.scrollIntoView({ block: "center", behavior: "smooth" });
}

const INPUT_TYPES = {
  text: "text",
  email: "email",
  phone: "tel",
  url: "url",
  date: "date",
  number: "number"
};

/** Today on the phone as yyyy-mm-dd: activities are usually logged the day they happen. */
function localToday() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return (
    now.getFullYear() + "-" + pad(now.getMonth() + 1) + "-" + pad(now.getDate())
  );
}

function isEmpty(value) {
  return (
    value === "" ||
    value === null ||
    value === undefined ||
    (Array.isArray(value) && value.length === 0)
  );
}

function buildControl(field, labels, id, dateDefaultToday) {
  const initial = field.defaultValue;
  if (field.type === "textarea") {
    const area = el("textarea", "sr-input sr-textarea");
    area.rows = 4;
    if (field.maxLength) area.maxLength = field.maxLength;
    if (initial != null) area.value = initial;
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
    if (initial != null) select.value = initial;
    return { node: select, read: () => select.value };
  }
  if (field.type === "multipicklist") {
    const group = el("div", "sr-choices");
    group.id = id;
    group.setAttribute("role", "group");
    const chosen = String(initial || "").split(";");
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
    box.checked = initial === true;
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
  if (initial != null) input.value = initial;
  else if (field.type === "date" && dateDefaultToday)
    input.value = localToday();
  return { node: input, read: () => input.value.trim() };
}

/**
 * options: labels, idPrefix, dateDefaultToday (new records), sendEmpty (edits: empty fields are sent so Salesforce
 * clears them). Returns { element, render(fields), collect(), mark(name, message), clear() }.
 */
export function createFieldList(options) {
  const labels = options.labels;
  const element = el("div", "sr-fields");
  element.append(el("p", "sr-hint", labels.loading || "…"));
  let controls = [];

  function mark(name, message) {
    const control = controls.find((item) => item.field.name === name);
    if (!control) return false;
    showError(control.error, message || labels.required);
    control.wrapper.classList.add("sr-invalid");
    return true;
  }

  function clear() {
    controls.forEach((control) => {
      showError(control.error);
      control.wrapper.classList.remove("sr-invalid");
    });
  }

  function render(fields) {
    element.replaceChildren();
    controls = [];
    (fields || []).forEach((field, index) => {
      const id = (options.idPrefix || "sr-field-") + index;
      const wrapper = el("div", "sr-field");
      const control = buildControl(field, labels, id, options.dateDefaultToday);
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
      const onChange = () => {
        showError(error);
        wrapper.classList.remove("sr-invalid");
      };
      wrapper.addEventListener("input", onChange);
      wrapper.addEventListener("change", onChange);
      element.append(wrapper);
      controls.push({ field, wrapper, error, read: control.read });
    });
  }

  function collect() {
    const values = {};
    let valid = true;
    controls.forEach((control) => {
      const value = control.read();
      if (isEmpty(value)) {
        if (control.field.required) {
          mark(control.field.name);
          valid = false;
        } else if (options.sendEmpty) {
          values[control.field.name] = Array.isArray(value) ? [] : "";
        }
        return;
      }
      values[control.field.name] = value;
    });
    return { values, valid };
  }

  return { element, render, collect, mark, clear };
}

/**
 * Shows INVALID_INPUT / SAVE_FAILED next to the fields they name (markExtra handles ids such as accountId) and the
 * rest in formError. Returns false for any other error, which the caller passes on.
 */
export function showSaveError(error, labels, fieldList, markExtra, formError) {
  if (
    !(error instanceof ApiError) ||
    (error.code !== "INVALID_INPUT" && error.code !== "SAVE_FAILED")
  )
    return false;
  const unplaced = [];
  Object.keys(error.fields || {}).forEach((name) => {
    if (
      !fieldList.mark(name, error.fields[name]) &&
      !markExtra(name, error.fields[name])
    )
      unplaced.push(error.fields[name]);
  });
  if (error.code !== "SAVE_FAILED") {
    showError(formError, [labels.checkFields].concat(unplaced).join(" "));
    return true;
  }
  // Salesforce's own text (often a validation rule, in the rep's language), after a plain-language first line. A rule
  // whose formula itself fails ("Validation Formula … Invalid") is the admin's to fix, not the rep's input.
  const detail = [error.message].concat(unplaced).join(" ");
  const intro = /Validation Formula .* Invalid/i.test(detail)
    ? labels.ruleError
    : labels.saveFailed;
  showError(formError, intro ? intro + "\n" + detail : detail);
  return true;
}
