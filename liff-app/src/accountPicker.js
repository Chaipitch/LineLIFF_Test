// Search-and-choose boxes: Account auto-complete (L4) and lookup fields on the forms (e.g. Main PreSales Engineer).
// Waits 300 ms after typing stops, needs minChars characters, cancels the request in flight when the rep keeps typing
// and hands back the record ID (never free text). All text is rendered with textContent.
import { ApiError } from "./api.js";

const DEBOUNCE_MS = 300;

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function format(template, ...values) {
  return String(template || "").replace(/\{(\d+)\}/g, (match, i) =>
    values[i] !== undefined ? values[i] : match
  );
}

/**
 * Generic search-and-choose box (Accounts, lookup fields). options: label (optional; omit when the caller renders one),
 * inputId, placeholder, searchingText, noResultsText, changeText, minChars, search(term, signal) → Promise of
 * [{ id, name, detail }], onSelect(item | null), onError(error), initial ({ id, name }, optional).
 */
export function createSearchPicker(options) {
  const minChars = options.minChars;
  const onSelect = options.onSelect || (() => {});
  const onError = options.onError;
  const root = el("div", options.label ? "sr-field" : "sr-picker");
  const input = el("input", "sr-input");
  input.type = "search";
  input.id = options.inputId;
  input.autocomplete = "off";
  input.setAttribute("enterkeyhint", "search");
  input.placeholder = format(options.placeholder, minChars);
  if (options.label) {
    const label = el("label", "sr-label", options.label);
    label.htmlFor = input.id;
    root.append(label);
  }
  const status = el("p", "sr-hint");
  status.setAttribute("aria-live", "polite");
  const list = el("ul", "sr-options");
  list.setAttribute("role", "listbox");
  const chosen = el("div", "sr-chosen");
  chosen.hidden = true;
  root.append(input, status, list, chosen);

  let timer;
  let inFlight;
  let selected = null;

  function clearResults(text) {
    list.replaceChildren();
    status.textContent = text || "";
  }

  function choose(item, silent) {
    selected = item;
    clearResults();
    input.hidden = true;
    const name = el("span", "sr-chosen-name", item.name);
    const change = el("button", "sr-link", options.changeText);
    change.type = "button";
    change.addEventListener("click", () => {
      selected = null;
      chosen.hidden = true;
      input.hidden = false;
      input.value = "";
      input.focus();
      onSelect(null);
    });
    chosen.replaceChildren(name, change);
    chosen.hidden = false;
    if (!silent) onSelect({ id: item.id, name: item.name });
  }

  function render(items) {
    if (!items.length) {
      clearResults(options.noResultsText);
      return;
    }
    status.textContent = "";
    list.replaceChildren(
      ...items.map((item) => {
        const li = el("li");
        const option = el("button", "sr-option");
        option.type = "button";
        option.setAttribute("role", "option");
        option.append(el("span", "sr-option-name", item.name));
        if (item.detail)
          option.append(el("span", "sr-option-detail", item.detail));
        option.addEventListener("click", () => choose(item));
        li.append(option);
        return li;
      })
    );
  }

  async function search(term) {
    if (inFlight) inFlight.abort();
    const controller = new AbortController();
    inFlight = controller;
    status.textContent = options.searchingText;
    try {
      const items = await options.search(term, controller.signal);
      if (inFlight === controller) render(items || []);
    } catch (error) {
      if (error instanceof ApiError && error.code === "ABORTED") return;
      if (inFlight === controller) {
        clearResults();
        onError(error);
      }
    } finally {
      if (inFlight === controller) inFlight = null;
    }
  }

  input.addEventListener("input", () => {
    clearTimeout(timer);
    const term = input.value.trim();
    if (term.length < minChars) {
      if (inFlight) inFlight.abort();
      clearResults();
      return;
    }
    timer = setTimeout(() => search(term), DEBOUNCE_MS);
  });

  if (options.initial && options.initial.id) choose(options.initial, true);

  return {
    element: root,
    selected: () => selected
  };
}

/** Account auto-complete (L4): GET /accounts?q=…, Accounts the rep can see. */
export function createAccountPicker(options) {
  const api = options.api;
  const labels = options.labels;
  return createSearchPicker({
    label: labels.accountLabel,
    inputId: "sr-account",
    placeholder: labels.accountPlaceholder,
    searchingText: labels.accountSearching,
    noResultsText: labels.accountNoResults,
    changeText: labels.change,
    minChars: options.minChars,
    onSelect: options.onSelect,
    onError: options.onError,
    search: async (term, signal) =>
      (await api.get("/accounts?q=" + encodeURIComponent(term), { signal }))
        .accounts
  });
}
