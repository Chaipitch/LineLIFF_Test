// Sales Report LIFF app — L2 shell.
// Initialises LIFF, sends the LINE ID token to /me and greets the rep by LINE display name.
// All text is rendered with textContent; no data is ever inserted as HTML.
import liff from "@line/liff";
import { createApi, ApiError } from "./api.js";

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

function showError(code) {
  const text =
    code === "UNAVAILABLE" || code === "CONFIG_MISSING"
      ? labels.errorUnavailable
      : labels.errorGeneric;
  showMessage(text, true);
}

function showHome(me, formKey) {
  const card = el("section", "sr-card");
  card.append(el("h1", "sr-title", labels[FORMS[formKey]] || labels.menuTitle));
  card.append(
    el("p", "sr-greeting", format(labels.hello, me.lineDisplayName || ""))
  );
  card.append(el("p", "sr-message", labels.comingSoon));
  render(card);
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
  try {
    const me = await api.get("/me");
    clearReloadFlag();
    showHome(me, requestedForm());
  } catch (error) {
    if (
      error instanceof ApiError &&
      error.code === "TOKEN_EXPIRED" &&
      reloadOnceForFreshToken()
    )
      return;
    showError(error instanceof ApiError ? error.code : undefined);
  }
}

start();
