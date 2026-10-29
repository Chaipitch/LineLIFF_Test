// Account auto-complete (L4): waits 300 ms after typing stops, needs minChars characters, cancels the request in
// flight when the rep keeps typing, shows at most maxResults Accounts and hands back the Account ID (never free text).
// All text is rendered with textContent.
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

export function createAccountPicker(options) {
  const api = options.api;
  const labels = options.labels;
  const minChars = options.minChars;
  const onSelect = options.onSelect;
  const onError = options.onError;
  const root = el("div", "sr-field");
  const label = el("label", "sr-label", labels.accountLabel);
  const input = el("input", "sr-input");
  input.type = "search";
  input.id = "sr-account";
  input.autocomplete = "off";
  input.setAttribute("enterkeyhint", "search");
  input.placeholder = format(labels.accountPlaceholder, minChars);
  label.htmlFor = input.id;
  const status = el("p", "sr-hint");
  status.setAttribute("aria-live", "polite");
  const list = el("ul", "sr-options");
  list.setAttribute("role", "listbox");
  const chosen = el("div", "sr-chosen");
  chosen.hidden = true;
  root.append(label, input, status, list, chosen);

  let timer;
  let inFlight;
  let selected = null;

  function clearResults(text) {
    list.replaceChildren();
    status.textContent = text || "";
  }

  function choose(account) {
    selected = account;
    clearResults();
    input.hidden = true;
    const name = el("span", "sr-chosen-name", account.name);
    const change = el("button", "sr-link", labels.change);
    change.type = "button";
    change.addEventListener("click", () => {
      selected = null;
      chosen.hidden = true;
      input.hidden = false;
      input.focus();
      onSelect(null);
    });
    chosen.replaceChildren(name, change);
    chosen.hidden = false;
    onSelect({ id: account.id, name: account.name });
  }

  function render(accounts) {
    if (!accounts.length) {
      clearResults(labels.accountNoResults);
      return;
    }
    status.textContent = "";
    list.replaceChildren(
      ...accounts.map((account) => {
        const item = el("li");
        const option = el("button", "sr-option");
        option.type = "button";
        option.setAttribute("role", "option");
        option.append(el("span", "sr-option-name", account.name));
        if (account.detail)
          option.append(el("span", "sr-option-detail", account.detail));
        option.addEventListener("click", () => choose(account));
        item.append(option);
        return item;
      })
    );
  }

  async function search(term) {
    if (inFlight) inFlight.abort();
    const controller = new AbortController();
    inFlight = controller;
    status.textContent = labels.accountSearching;
    try {
      const result = await api.get("/accounts?q=" + encodeURIComponent(term), {
        signal: controller.signal
      });
      if (inFlight === controller) render(result.accounts || []);
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

  return {
    element: root,
    selected: () => selected
  };
}
