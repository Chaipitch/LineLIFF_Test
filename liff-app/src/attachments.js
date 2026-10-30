// Photos and files for Log Activity (L5b, D-34). The rep picks photos (camera or gallery) or files; photos are
// shrunk on the phone (longest side 1600 px, JPEG) so they upload quickly and stay under the per-file limit. Files
// are uploaded one by one after the Task is saved, each as raw bytes to /activity/files. All text uses textContent.

const MAX_SIDE_PX = 1600;
const JPEG_QUALITY = 0.82;
const SHRINKABLE = /^image\/(jpeg|png|heic|heif|webp)$/;

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

function extensionOf(name) {
  const dot = String(name || "").lastIndexOf(".");
  return dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
}

function baseName(name) {
  const dot = String(name || "").lastIndexOf(".");
  return dot > 0 ? name.slice(0, dot) : name || "photo";
}

function sizeText(bytes) {
  return bytes >= 1024 * 1024
    ? (bytes / (1024 * 1024)).toFixed(1) + " MB"
    : Math.max(1, Math.round(bytes / 1024)) + " KB";
}

function loadImage(url) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = url;
  });
}

/** JPEG copy no larger than MAX_SIDE_PX; null when the browser can't read the image (e.g. HEIC on Android). */
async function shrink(file) {
  const url = URL.createObjectURL(file);
  try {
    const image = await loadImage(url);
    const scale = Math.min(
      1,
      MAX_SIDE_PX / Math.max(image.naturalWidth, image.naturalHeight)
    );
    const canvas = document.createElement("canvas");
    canvas.width = Math.round(image.naturalWidth * scale);
    canvas.height = Math.round(image.naturalHeight * scale);
    canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height);
    return await new Promise((resolve) =>
      canvas.toBlob(resolve, "image/jpeg", JPEG_QUALITY)
    );
  } catch {
    return null;
  } finally {
    URL.revokeObjectURL(url);
  }
}

export function createAttachmentPicker(options) {
  const labels = options.labels;
  const limits = options.limits || {};
  const types = (limits.types || []).map((type) => String(type).toLowerCase());
  const maxFiles = limits.maxFiles || 0;
  const maxBytes = (limits.maxSizeMb || 0) * 1024 * 1024;
  const jpegAllowed =
    types.indexOf("jpg") !== -1 || types.indexOf("jpeg") !== -1;

  const root = el("div", "sr-field sr-attachments");
  root.append(el("p", "sr-label", labels.attachmentsLabel));
  const list = el("ul", "sr-files");
  const error = el("p", "sr-error");
  error.setAttribute("role", "alert");
  error.hidden = true;
  const input = document.createElement("input");
  input.type = "file";
  input.multiple = true;
  input.hidden = true;
  const accept = types.map((type) => "." + type);
  if (jpegAllowed) accept.push("image/*");
  if (types.indexOf("pdf") !== -1) accept.push("application/pdf");
  input.accept = accept.join(",");
  const add = el(
    "button",
    "sr-button sr-secondary sr-add-file",
    labels.addFile
  );
  add.type = "button";
  add.addEventListener("click", () => input.click());
  root.append(list, error, add, input);

  const files = [];

  function showError(message) {
    error.textContent = message || "";
    error.hidden = !message;
  }

  function render() {
    list.replaceChildren(
      ...files.map((file, index) => {
        const item = el("li", "sr-file");
        if (file.preview) {
          const thumb = document.createElement("img");
          thumb.className = "sr-file-thumb";
          thumb.alt = "";
          thumb.src = file.preview;
          item.append(thumb);
        } else {
          item.append(el("span", "sr-file-icon", file.extension.toUpperCase()));
        }
        const text = el("span", "sr-file-text");
        text.append(
          el("span", "sr-file-name", file.name),
          el("span", "sr-file-size", sizeText(file.blob.size))
        );
        const remove = el("button", "sr-link", labels.removeFile);
        remove.type = "button";
        remove.addEventListener("click", () => {
          if (file.preview) URL.revokeObjectURL(file.preview);
          files.splice(index, 1);
          showError();
          render();
        });
        item.append(text, remove);
        return item;
      })
    );
    add.hidden = files.length >= maxFiles;
  }

  async function prepare(file) {
    let blob = file;
    let name = file.name || "photo.jpg";
    if (jpegAllowed && SHRINKABLE.test(file.type)) {
      const small = await shrink(file);
      if (small) {
        blob = small;
        name = baseName(name) + ".jpg";
      }
    }
    const extension = extensionOf(name);
    if (types.indexOf(extension) === -1)
      return { error: format(labels.fileTypeNotAllowed, file.name) };
    if (blob.size > maxBytes)
      return {
        error: format(labels.fileTooLarge, file.name, limits.maxSizeMb)
      };
    const preview =
      blob.type.indexOf("image/") === 0 ? URL.createObjectURL(blob) : null;
    return { file: { name, extension, blob, preview } };
  }

  input.addEventListener("change", async () => {
    const chosen = Array.from(input.files || []);
    input.value = "";
    const problems = [];
    for (const file of chosen) {
      if (files.length >= maxFiles) {
        problems.push(format(labels.maxFiles, maxFiles));
        break;
      }
      const result = await prepare(file);
      if (result.error) problems.push(result.error);
      else files.push(result.file);
    }
    showError(problems.join(" "));
    render();
  });

  render();
  return {
    element: root,
    files: () => files.slice()
  };
}

/**
 * Uploads the files to the Task one by one; onProgress(done, total) before each. Resolves to the files that failed,
 * so the saved screen can offer "Try again" for just those.
 */
export async function uploadFiles(api, taskId, files, onProgress) {
  const failed = [];
  for (let i = 0; i < files.length; i++) {
    if (onProgress) onProgress(i + 1, files.length);
    const file = files[i];
    try {
      await api.upload(
        "/activity/files?taskId=" +
          encodeURIComponent(taskId) +
          "&name=" +
          encodeURIComponent(file.name),
        file.blob
      );
    } catch {
      failed.push(file);
    }
  }
  return failed;
}
