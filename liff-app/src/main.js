// Sales Report LIFF app.
// Initialises LIFF and sends the LINE ID token to /connection. Not linked yet: the one-time link page (Salesforce
// login) opens right away in the phone's browser (D-42); after Connect the link page brings the rep back to their form. Linked: greets the rep and shows the
// form named by ?form= (activity = Log Activity, L5a; opportunity = Update Opportunity, L5c).
// All text is rendered with textContent; no data is ever inserted as HTML.
import liff from "@line/liff";
import { createApi, ApiError } from "./api.js";
import { createAccountPicker } from "./accountPicker.js";
import { createActivityForm } from "./activityForm.js";
import { createOpportunityForm } from "./opportunityForm.js";
import { uploadFiles } from "./attachments.js";

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
  if (code === "RATE_LIMITED") return labels.errorRateLimited;
  if (code === "NO_ACCESS") return labels.errorNoAccess;
  return labels.errorGeneric;
}

// Unexpected failures (server errors) show the request ID so the rep can quote it to support (D-45).
function showError(code, reference) {
  const text = errorText(code);
  showMessage(
    reference && labels.errorReference
      ? text + "\n" + format(labels.errorReference, reference)
      : text,
    true
  );
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

/** Forms can be switched off in Sales Report Settings; a missing flag means on. */
function formEnabled(formKey) {
  const forms = config.forms || {};
  return forms[formKey] !== false;
}

function showHome(me, formKey) {
  const card = el("section", "sr-card");
  card.append(el("h1", "sr-title", labels[FORMS[formKey]] || labels.menuTitle));
  if (formKey === "activity") {
    const form = createActivityForm({
      api: apiClient,
      labels,
      createPicker: newPicker,
      attachments: config.attachments,
      onSaved: (result, failed) => showActivitySaved(me, result, failed),
      onError: handleApiError
    });
    card.append(form.element);
  } else if (formKey === "opportunity" && !formEnabled("opportunity")) {
    card.append(el("p", "sr-message", labels.comingSoon));
  } else if (formKey === "opportunity") {
    const form = createOpportunityForm({
      api: apiClient,
      labels,
      createPicker: newPicker,
      minChars: (config.accountSearch || {}).minChars || 2,
      onSaved: (result) => showOpportunitySaved(me, result),
      onError: handleApiError
    });
    card.append(form.element);
  } else {
    // Opened without ?form= (e.g. "Open Sales Report in LINE" after the one-time login): let the rep pick a form.
    card.append(button(labels.activityTitle, () => showHome(me, "activity")));
    if (formEnabled("opportunity"))
      card.append(
        button(labels.opportunityTitle, () => showHome(me, "opportunity"), true)
      );
  }
  render(identityBar(me), card);
}

/** Compact "who is logged in" bar: LINE name and the linked Salesforce user. */
function identityBar(me) {
  const name = String(me.lineDisplayName || "").trim();
  const bar = el("header", "sr-identity");
  bar.append(
    el("span", "sr-avatar", name ? name.charAt(0).toUpperCase() : "?")
  );
  const who = el("div", "sr-identity-text");
  who.append(el("p", "sr-identity-name", name));
  who.append(
    el(
      "p",
      "sr-identity-sub",
      format(labels.linkedAs, me.salesforceUserName || "")
    )
  );
  bar.append(who);
  return bar;
}

function showOpportunitySaved(me, result) {
  const card = el("section", "sr-card");
  card.append(el("h1", "sr-title", labels.opportunityTitle));
  card.append(
    el("p", "sr-message", format(labels.opportunitySaved, result.name || ""))
  );
  card.append(button(labels.updateAnother, () => showHome(me, "opportunity")));
  if (liff.isInClient())
    card.append(button(labels.close, () => liff.closeWindow(), true));
  render(identityBar(me), card);
}

function showActivitySaved(me, result, failed) {
  const card = el("section", "sr-card");
  card.append(el("h1", "sr-title", labels.activityTitle));
  card.append(
    el("p", "sr-message", format(labels.activitySaved, result.subject || ""))
  );
  if (failed && failed.length) {
    card.append(
      el("p", "sr-error", format(labels.uploadFailed, failed.length))
    );
    const retry = button(labels.retry, async () => {
      retry.disabled = true;
      const stillFailed = await uploadFiles(
        apiClient,
        result.id,
        failed,
        (done, total) => {
          retry.textContent = format(labels.uploading, done, total);
        }
      );
      showActivitySaved(me, result, stillFailed);
    });
    card.append(retry);
  }
  card.append(
    button(
      labels.logAnother,
      () => showHome(me, "activity"),
      failed && failed.length > 0
    )
  );
  if (liff.isInClient())
    card.append(button(labels.close, () => liff.closeWindow(), true));
  render(identityBar(me), card);
}

let apiClient;

/** Set when the app sends the rep to the Salesforce login; if they come back unlinked soon after, show a button instead
 * of redirecting again (they pressed Back or cancelled), so the app can never loop. */
const LOGIN_STARTED = "salesReport.loginStartedAt";
const LOGIN_RETRY_MS = 2 * 60 * 1000;
// localStorage (not sessionStorage), so the marker survives closing and reopening the LIFF window.
function loginRecentlyStarted() {
  try {
    const at = Number(localStorage.getItem(LOGIN_STARTED) || 0);
    return Date.now() - at < LOGIN_RETRY_MS;
  } catch {
    return false;
  }
}

function markLoginStarted(value) {
  try {
    if (value) localStorage.setItem(LOGIN_STARTED, String(Date.now()));
    else localStorage.removeItem(LOGIN_STARTED);
  } catch {
    // Storage blocked: the Connect buttons still work.
  }
}

/** A fresh one-time link page URL, carrying the form the rep came for so the link page returns straight to it. */
async function newLinkUrl(api) {
  const result = await api.post("/link/start", {});
  const form = requestedForm();
  return form
    ? result.linkUrl + "&form=" + encodeURIComponent(form)
    : result.linkUrl;
}

/**
 * One-time login in the phone's own browser (D-42): LINE's built-in browser can't do Salesforce's passkey / Face ID
 * verification. After Connect, the link page's return address (liff.line.me) opens LINE on the form; this window
 * also re-checks when it becomes visible again.
 */
async function startLogin(api) {
  const url = await newLinkUrl(api);
  markLoginStarted(true);
  liff.openWindow({ url, external: true });
}

let onConnectScreen = false;

/** Not linked yet. opened = the browser login was just opened, so tell the rep to finish there. */
function showConnect(api, opened) {
  onConnectScreen = true;
  const card = el("section", "sr-card");
  card.append(el("h1", "sr-title", labels.connectTitle));
  card.append(
    el("p", "sr-message", opened ? labels.connectWaiting : labels.connectBody)
  );
  const login = button(labels.connectButton, async () => {
    login.disabled = true;
    try {
      await startLogin(api);
      showConnect(api, true);
    } catch (error) {
      login.disabled = false;
      handleApiError(error);
    }
  });
  card.append(login);
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
  if (error instanceof ApiError)
    showError(error.code, error.status >= 500 ? error.reference : null);
  else showError();
}

async function checkMe(api) {
  showLoading();
  try {
    const me = await api.get("/connection");
    clearReloadFlag();
    onConnectScreen = false;
    if (me.linked) {
      markLoginStarted(false);
      showHome(me, requestedForm());
    } else if (loginRecentlyStarted()) {
      showConnect(api, true);
    } else {
      // Open the browser login right away; the screen behind it says to finish there (and can reopen it).
      await startLogin(api);
      showConnect(api, true);
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
  // Back from the phone's browser after connecting there: check again without a tap.
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible" && onConnectScreen) checkMe(api);
  });
  await checkMe(api);
}

start();
