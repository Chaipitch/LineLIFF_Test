// Calls to the Sales Report Apex REST endpoints on the same Site.
// The LINE ID token goes in X-Line-Id-Token: Salesforce would reject a non-Salesforce token in Authorization.

const TIMEOUT_MS = 15000;
// A 4 MB file over a slow mobile connection needs longer than a JSON call.
const UPLOAD_TIMEOUT_MS = 90000;

export class ApiError extends Error {
  constructor(status, code, message, fields) {
    super(message || code || `HTTP ${status}`);
    this.status = status;
    this.code = code;
    // Field API name → message, when the server can point at fields (INVALID_INPUT, SAVE_FAILED).
    this.fields = fields || null;
  }
}

async function parseBody(response) {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

export function createApi(apiBase, getIdToken) {
  async function request(method, path, options) {
    const body = options ? options.body : undefined;
    const raw = options ? options.raw : undefined;
    const signal = options ? options.signal : undefined;
    const controller = new AbortController();
    const timer = setTimeout(
      () => controller.abort(),
      raw !== undefined ? UPLOAD_TIMEOUT_MS : TIMEOUT_MS
    );
    if (signal)
      signal.addEventListener("abort", () => controller.abort(), {
        once: true
      });

    let response;
    try {
      response = await fetch(apiBase + path, {
        method,
        credentials: "same-origin",
        cache: "no-store",
        headers: {
          Accept: "application/json",
          "X-Line-Id-Token": getIdToken() || "",
          ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
          ...(raw !== undefined
            ? { "Content-Type": "application/octet-stream" }
            : {})
        },
        body:
          raw !== undefined
            ? raw
            : body !== undefined
              ? JSON.stringify(body)
              : undefined,
        signal: controller.signal
      });
    } catch (error) {
      throw new ApiError(
        0,
        error && error.name === "AbortError" ? "ABORTED" : "NETWORK",
        error && error.message
      );
    } finally {
      clearTimeout(timer);
    }

    const data = await parseBody(response);
    if (!response.ok) {
      const detail = data && data.error ? data.error : {};
      throw new ApiError(
        response.status,
        detail.code || "HTTP_" + response.status,
        detail.message,
        detail.fields
      );
    }
    return data;
  }

  return {
    get: (path, options) => request("GET", path, options),
    post: (path, body, options) =>
      request("POST", path, Object.assign({}, options, { body })),
    /** POST raw bytes (a file) instead of JSON. */
    upload: (path, blob, options) =>
      request("POST", path, Object.assign({}, options, { raw: blob }))
  };
}
