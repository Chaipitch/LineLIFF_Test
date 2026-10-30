// Sales Report LIFF app.
// Initialises LIFF and sends the LINE ID token to /me. Not linked yet: "Connect Salesforce" opens the one-time link
// page in the browser (D-15) and /me is checked again when the rep comes back. Linked: greets the rep and shows the
// form named by ?form= (activity = Log Activity, L5a; opportunity is still coming soon).
// All text is rendered with textContent; no data is ever inserted as HTML.
import liff from "@line/liff";
import { createApi, ApiError } from "./api.js";
import { createAccountPicker } from "./accountPicker.js";
import { createActivityForm } from "./activityForm.js";

const RELOAD_FLAG = "salesReport.reloadedForToken";
const FORMS = { activity: "activityTitle", opportunity: "opportunityTitle" };

const root = document.getElementById("app");
const config = readConfig(root);
const labels = config.labels || {};

function readConfig(element) {
  try {
    return JSON.parse(element.dataset.config || "{}");
  } catch {
    return {};
  }
}

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

function render(...children) {
  root.replaceChildren(...children);
}

function showLoading() {
  render(el("p", "sr-status", labels.loading || "…"));
}

function showMessage(text, withClose) {
  const card = el("section", "sr-card");
  card.append(el("p", "sr-message", text));
  if (withClose && liff.isInClient()) {
    const button = el("button", "sr-button", labels.close);
    button.type = "button";
    button.addEventListener("click", () => liff.closeWindow());
    card.append(button);
  }
  render(card);
}

function errorText(code) {
  if (code === "UNAVAILABLE" || code === "CONFIG_MISSING")
    return labels.errorUnavailable;
  if (code === "NOT_AUTHORIZED") return labels.errorNotAuthorized;
  return labels.errorGeneric;
}

function showError(code) {
  showMessage(errorText(code), true);
}

function button(text, onClick, secondary) {
  const node = el(
    "button",
    secondary ? "sr-button sr-secondary" : "sr-button",
    text
  );
  node.type = "button";
  node.addEventListener("click", onClick);
  return node;
}

function newPicker(onSelect) {
  const search = config.accountSearch || {};
  return createAccountPicker({
    api: apiClient,
    labels,
    minChars: search.minChars || 2,
    onSelect: onSelect || (() => {}),
    onError: handleApiError
  });
}

function showHome(me, formKey) {
  const card = el("section", "sr-card");
  card.append(el("h1", "sr-title", labels[FORMS[formKey]] || labels.menuTitle));
  card.append(
    el("p", "sr-greeting", format(labels.hello, me.lineDisplayName || ""))
  );
  card.append(
    el("p", "sr-sub", format(labels.linkedAs, me.salesforceUserName || ""))
  );
  if (formKey === "activity") {
    const form = createActivityForm({
      api: apiClient,
      labels,
      createPicker: newPicker,
      onSaved: (result) => showActivitySaved(me, result),
      onError: handleApiError
    });
    card.append(form.element);
  } else {
    card.append(newPicker().element);
    card.append(el("p", "sr-message", labels.comingSoon));
  }
  render(card);
}

function showActivitySaved(me, result) {
  const card = el("section", "sr-card");
  card.append(el("h1", "sr-title", labels.activityTitle));
  card.append(
    el("p", "sr-message", format(labels.activitySaved, result.subject || ""))
  );
  card.append(button(labels.logAnother, () => showHome(me, "activity")));
  if (liff.isInClient())
    card.append(button(labels.close, () => liff.closeWindow(), true));
  render(card);
}

let waitingForLink = false;
let apiClient;

function showConnect(api) {
  waitingForLink = false;
  const card = el("section", "sr-card");
  card.append(el("h1", "sr-title", labels.connectTitle));
  card.append(el("p", "sr-message", labels.connectBody));
  const connect = button(labels.connectButton, async () => {
    connect.disabled = true;
    try {
      const result = await api.post("/link/start", {});
      waitingForLink = true;
      liff.openWindow({ url: result.linkUrl, external: true });
      showWaiting(api);
    } catch (error) {
      connect.disabled = false;
      handleApiError(error);
    }
  });
  card.append(connect);
  render(card);
}

function showWaiting(api) {
  const card = el("section", "sr-card");
  card.append(el("h1", "sr-title", labels.connectTitle));
  card.append(el("p", "sr-message", labels.connectWaiting));
  card.append(button(labels.connectCheck, () => checkMe(api)));
  render(card);
}

function handleApiError(error) {
  if (error instanceof ApiError && error.code === "NOT_LINKED") {
    checkMe(apiClient);
    return;
  }
  if (
    error instanceof ApiError &&
    error.code === "TOKEN_EXPIRED" &&
    reloadOnceForFreshToken()
  )
    return;
  showError(error instanceof ApiError ? error.code : undefined);
}

async function checkMe(api) {
  showLoading();
  try {
    const me = await api.get("/me");
    clearReloadFlag();
    if (me.linked) {
      waitingForLink = false;
      showHome(me, requestedForm());
    } else if (waitingForLink) {
      showWaiting(api);
    } else {
      showConnect(api);
    }
  } catch (error) {
    handleApiError(error);
  }
}

function requestedForm() {
  const form = new URLSearchParams(window.location.search).get("form");
  return Object.prototype.hasOwnProperty.call(FORMS, form) ? form : null;
}

/** One automatic reload when LINE's ID token (valid 1 hour) has expired; never loops. */
function reloadOnceForFreshToken() {
  try {
    if (sessionStorage.getItem(RELOAD_FLAG)) return false;
    sessionStorage.setItem(RELOAD_FLAG, "1");
  } catch {
    return false;
  }
  showMessage(labels.errorSessionExpired);
  window.location.reload();
  return true;
}

function clearReloadFlag() {
  try {
    sessionStorage.removeItem(RELOAD_FLAG);
  } catch {
    // Storage blocked: nothing to clear.
  }
}

async function start() {
  showLoading();
  if (!config.liffId || config.enabled === false) {
    showError("UNAVAILABLE");
    return;
  }

  try {
    await liff.init({ liffId: config.liffId });
  } catch {
    showError();
    return;
  }

  if (!liff.isInClient() && !liff.isLoggedIn()) {
    showMessage(labels.openInLine);
    return;
  }

  const idToken = liff.getIDToken();
  if (!idToken) {
    showError();
    return;
  }

  const api = createApi(config.apiBase, () => liff.getIDToken());
  apiClient = api;
  // Coming back from the browser after the one-time login: check again without a tap.
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible" && waitingForLink) checkMe(api);
  });
  await checkMe(api);
}

start();
