const FILE_FIELDS = [
//  "cvs",
//  "ips",
  "details",
  "confirmation",
  "impact",
  "mitigation",
  "references"
];

let currentFinding = null;
let allPrewriteOptions = null;
const imagePickerState = {
  targetId: null,
  range: null,
  selectedFilename: null
};

const cvssOverrideEnabled = () => document.getElementById("cvss-override-enabled");
const cvssOverrideScore = () => document.getElementById("cvss-override-score");

var c = new CVSS("cvssboard", {
    onchange: function() {
        window.location.hash = c.get().vector;
        c.vector.setAttribute('href', '#' + c.get().vector);
        applyCVSSScoreDisplay();
    }
});
if (window.location.hash.substring(1).length > 0) {
    c.set(decodeURIComponent(window.location.hash.substring(1)));
}

function getImagePickerModal() {
  return document.getElementById("image-picker-modal");
}

function getImagePickerList() {
  return document.getElementById("image-picker-list");
}

function getImagePickerCaption() {
  return document.getElementById("image-picker-caption");
}

function getImagePickerInsertButton() {
  return document.getElementById("image-picker-insert");
}

function getImagePickerMessage() {
  return document.getElementById("image-picker-message");
}

function getFieldDisplayName(field) {
  return field.replace(".txt", "").replace(/[-_]/g, " ");
}

function buildImageUrl(filename, findingName = currentFinding) {
  return `/api/findings/${encodeURIComponent(findingName)}/images/${encodeURIComponent(filename)}`;
}

function rangeBelongsToEditor(range, editor) {
  if (!range || !editor) return false;
  const container = range.commonAncestorContainer;
  return container === editor || editor.contains(container);
}

function createCollapsedRangeAtEnd(editor) {
  const range = document.createRange();
  range.selectNodeContents(editor);
  range.collapse(false);
  return range;
}

function closeImagePicker() {
  const modal = getImagePickerModal();
  if (modal) {
    modal.classList.add("hidden");
  }
  imagePickerState.targetId = null;
  imagePickerState.range = null;
  imagePickerState.selectedFilename = null;
}

function selectImagePickerImage(filename) {
  imagePickerState.selectedFilename = filename;
  const insertButton = getImagePickerInsertButton();
  if (insertButton) {
    insertButton.disabled = !filename;
  }

  document.querySelectorAll(".image-picker-item").forEach((item) => {
    item.classList.toggle("selected", item.dataset.filename === filename);
  });
}

function renderImagePickerImages(images) {
  const list = getImagePickerList();
  const message = getImagePickerMessage();
  const insertButton = getImagePickerInsertButton();
  if (!list || !message || !insertButton) return;

  list.innerHTML = "";
  imagePickerState.selectedFilename = null;
  insertButton.disabled = true;

  if (!images.length) {
    message.textContent = "Upload at least one image for this finding before inserting it into the editor.";
    return;
  }

  message.textContent = "Choose one of the uploaded images, then add an optional caption.";
  images.forEach((filename, index) => {
    const option = document.createElement("button");
    option.type = "button";
    option.className = "image-picker-item";
    option.dataset.filename = filename;

    const img = document.createElement("img");
    img.src = buildImageUrl(filename);
    img.alt = filename;

    const label = document.createElement("span");
    label.textContent = filename;

    option.appendChild(img);
    option.appendChild(label);
    option.addEventListener("click", () => selectImagePickerImage(filename));

    list.appendChild(option);
    if (index === 0) {
      selectImagePickerImage(filename);
    }
  });
}

async function openImagePicker(targetId, range) {
  if (!currentFinding) {
    setStatus("Select a finding before inserting an image", true);
    return;
  }

  const editor = document.getElementById(targetId);
  if (!editor) return;

  imagePickerState.targetId = targetId;
  imagePickerState.range = rangeBelongsToEditor(range, editor) ? range.cloneRange() : createCollapsedRangeAtEnd(editor);
  imagePickerState.selectedFilename = null;

  const caption = getImagePickerCaption();
  if (caption) {
    caption.value = "";
  }

  const modal = getImagePickerModal();
  if (modal) {
    modal.classList.remove("hidden");
  }

  try {
    const data = await fetchJSON(`/api/findings/${encodeURIComponent(currentFinding)}/images`);
    renderImagePickerImages(data.images || []);
  } catch (e) {
    closeImagePicker();
    setStatus(e.message, true);
  }
}

window.openImagePicker = openImagePicker;

function insertImageIntoEditor() {
  const filename = imagePickerState.selectedFilename;
  const editor = imagePickerState.targetId ? document.getElementById(imagePickerState.targetId) : null;
  if (!filename || !editor) {
    closeImagePicker();
    return;
  }

  editor.focus();

  const selection = window.getSelection();
  const range = rangeBelongsToEditor(imagePickerState.range, editor)
    ? imagePickerState.range.cloneRange()
    : createCollapsedRangeAtEnd(editor);

  selection.removeAllRanges();
  selection.addRange(range);

  const figure = document.createElement("figure");
  figure.className = "finding-image";
  figure.setAttribute("data-image-filename", filename);

  const img = document.createElement("img");
  img.src = buildImageUrl(filename);
  img.alt = filename;
  img.setAttribute("data-image-filename", filename);

  figure.appendChild(img);

  const captionText = (getImagePickerCaption()?.value || "").trim();
  if (captionText) {
    const figcaption = document.createElement("figcaption");
    figcaption.textContent = captionText;
    figure.appendChild(figcaption);
  }

  const spacer = document.createElement("div");
  spacer.appendChild(document.createElement("br"));

  const fragment = document.createDocumentFragment();
  fragment.appendChild(figure);
  fragment.appendChild(spacer);

  range.deleteContents();
  range.insertNode(fragment);

  const newRange = document.createRange();
  newRange.setStartAfter(spacer);
  newRange.collapse(true);
  selection.removeAllRanges();
  selection.addRange(newRange);

  closeImagePicker();
}

async function requestImageDelete(filename, deleteEverywhere = false) {
  const suffix = deleteEverywhere ? "?delete_everywhere=1" : "";
  const response = await fetch(`/api/findings/${encodeURIComponent(currentFinding)}/images/${encodeURIComponent(filename)}${suffix}`, {
    method: "DELETE"
  });

  let data = {};
  try {
    data = await response.json();
  } catch (e) {}

  if (!response.ok) {
    const error = new Error(data.error || response.statusText);
    error.data = data;
    throw error;
  }

  return data;
}

async function deleteImage(filename) {
  if (!confirm(`Delete "${filename}"?`)) {
    return;
  }

  try {
    const result = await requestImageDelete(filename);
    await loadImages();
    if ((result.removed_references || []).length) {
      await selectFinding(currentFinding);
    }
    setStatus("Image deleted");
  } catch (e) {
    const data = e.data || {};
    if (!data.requires_confirmation) {
      setStatus(e.message, true);
      return;
    }

    const referenceSummary = (data.references || [])
      .map((ref) => `${getFieldDisplayName(ref.field)} (${ref.count})`)
      .join(", ");

    const shouldDeleteEverywhere = confirm(
      `"${filename}" is still embedded in ${referenceSummary}. Delete it everywhere and remove those embedded references?`
    );

    if (!shouldDeleteEverywhere) {
      setStatus("Image deletion cancelled");
      return;
    }

    try {
      await requestImageDelete(filename, true);
      await loadImages();
      await selectFinding(currentFinding);
      setStatus("Image deleted everywhere");
    } catch (forcedError) {
      setStatus(forcedError.message, true);
    }
  }
}

function normalizeCVSSOverrideScore(value) {
  if (value === null || value === undefined || value === "") {
    return "";
  }

  const parsed = Number.parseFloat(value);
  if (Number.isNaN(parsed) || parsed < 0 || parsed > 10) {
    return "";
  }

  return parsed.toFixed(1);
}

function setCVSSSeverityForScore(scoreValue) {
  const parsed = Number.parseFloat(scoreValue);
  if (Number.isNaN(parsed)) {
    c.severity.className = "severity";
    c.severity.textContent = "?";
    c.severity.title = "Not defined";
    return;
  }

  const rating = c.severityRating(parsed);
  c.severity.className = `${rating.name} severity`;
  c.severity.innerHTML = `${rating.name}<sub>${rating.bottom} - ${rating.top}</sub>`;
  c.severity.title = `${rating.bottom} - ${rating.top}`;
}

function getManualCVSSOverride() {
  const enabled = cvssOverrideEnabled();
  const scoreInput = cvssOverrideScore();

  if (!enabled || !scoreInput || !enabled.checked) {
    return "";
  }

  return normalizeCVSSOverrideScore(scoreInput.value);
}

function setManualCVSSOverride(value) {
  const enabled = cvssOverrideEnabled();
  const scoreInput = cvssOverrideScore();
  if (!enabled || !scoreInput) return;

  const normalized = normalizeCVSSOverrideScore(value);
  enabled.checked = normalized !== "";
  scoreInput.disabled = !enabled.checked;
  scoreInput.value = normalized;
}

function clearManualCVSSOverride() {
  setManualCVSSOverride("");
}

function applyCVSSScoreDisplay() {
  const calculatedScore = c.calculate();
  const overrideScore = getManualCVSSOverride();
  const displayedScore = overrideScore || calculatedScore;

  c.score.textContent = displayedScore;
  setCVSSSeverityForScore(displayedScore);
}

function validateManualCVSSOverride() {
  const enabled = cvssOverrideEnabled();
  const scoreInput = cvssOverrideScore();
  if (!enabled || !scoreInput || !enabled.checked) {
    return true;
  }

  const normalized = normalizeCVSSOverrideScore(scoreInput.value);
  if (!normalized) {
    setStatus("Manual CVSS override must be between 0.0 and 10.0", true);
    scoreInput.focus();
    return false;
  }

  scoreInput.value = normalized;
  return true;
}

async function loadPrewrites() {
  const select = document.getElementById("prewrite-select");
  const search = document.getElementById("prewrite-search");
  if (!select || !search) return;

  try {
    const data = await fetchJSON("/api/prewrites");
    const names = data.prewrites || [];

    // Build full option list
    allPrewriteOptions = names.map((name) => {
      const opt = document.createElement("option");
      opt.value = name;
      opt.textContent = name;
      return opt;
    });

    // Initial render: NONE + all
    renderPrewriteOptions("");

    // Wire search
    search.addEventListener("input", () =>{
      const term = search.value.toLowerCase();
      renderPrewriteOptions(term);
    });
  } catch (e) {
    console.error(e);
  }

  function renderPrewriteOptions(term) {
    // Reset select with NONE
    select.innerHTML = "";
    const none = document.createElement("option");
    none.value = "";
    none.textContent = "NONE";
    select.appendChild(none);

    allPrewriteOptions
      .filter(
        (o) =>
	  !term ||
	  o.textContent.toLowerCase().includes(term)
      )
      .forEach((o) => select.appendChild(o));
  }
}

async function fetchJSON(url, options) {
  const res = await fetch(url, options);
  if (!res.ok) {
    let msg = res.statusText;
    try {
      const data = await res.json();
      if (data.error) msg = data.error;
    } catch (e) {}
    throw new Error(msg);
  }
  return res.json();
}

async function loadFindings() {
  const data = await fetchJSON("/api/findings");
  const list = document.getElementById("finding-list");
  list.innerHTML = "";

  data.findings.forEach(name => {
    const li = document.createElement("li");

    // Finding name (left side)
    const nameSpan = document.createElement("span");
    nameSpan.textContent = name;
    nameSpan.addEventListener("click", () => selectFinding(name));
    
    // Red X button (right side)
    const deleteBtn = document.createElement("button");
    deleteBtn.className = "delete-finding-btn";
    deleteBtn.title = "Delete finding";
    deleteBtn.innerHTML = "x"; // Red X symbol

    deleteBtn.addEventListener("click", async (e) => {
      e.stopPropagation();

      if (!confirm(`Delete "${name}"? This cannot be undone.`)) return;

      try {
        await fetchJSON(`/api/findings/${encodeURIComponent(name)}`, {
          method: "DELETE"
	});
	setStatus(`"${name}" deleted`);
        await loadFindings(); // Refresh list
        if (currentFinding === name){
          currentFinding = null;
          setStatus(""); // Clear form
	}
      } catch (e) {
        setStatus(e.message, true);
      }
    });

    li.appendChild(nameSpan);
    li.appendChild(deleteBtn);

    if (name === currentFinding) {
      li.classList.add("active");
    }

    list.appendChild(li);
  });
}

function setStatus(msg, isError = false) {
  const el = document.getElementById("status");
  el.textContent = msg || "";
  el.style.color = isError ? "red" : "#555";
}

function addRow() {
  const tableBody = document.querySelector('#textTable tbody');
  const lastRow = tableBody.querySelector('tr.text-row:last-child');
  let newRow
  if (lastRow) {
    newRow = lastRow.cloneNode(true);

    // Clear textarea values in the cloned row
    newRow.querySelectorAll('textarea').forEach(t => t.value = '');
  } else {
    newRow = document.createElement('tr');
    newRow.className = 'text-row';

    // 4 columns with textareas
    for (let i = 0; i < 4; i++) {
      const td = document.createElement('td');
      const ta = document.createElement('textarea');
      ta.rows = 1;
      td.appendChild(ta);
      newRow.appendChild(td);
    }

    // Button column
    const btnTd = document.createElement('td');

    const addBtn = document.createElement('button');
    addBtn.type = 'button';
    addBtn.className = 'add-row-btn';
    addBtn.textContent = '+';
    addBtn.onclick = addRow;

    const delBtn = document.createElement('button');
    delBtn.type = 'button';
    delBtn.className = 'delete-row-btn';
    delBtn.textContent = '-';
    delBtn.onclick = function () {
      deleteRow(this);
    };

    btnTd.appendChild(addBtn);
    btnTd.appendChild(delBtn);
    newRow.appendChild(btnTd);
  }
  // Ensure the buttons in the new row also works
  newRow.querySelector('.add-row-btn').onclick = addRow;
  newRow.querySelector('.delete-row-btn').onclick = function () {
    deleteRow(this);
  };

  tableBody.appendChild(newRow);
  return newRow
}
function deleteRow(button) {
  const row = button.closest('tr');
  const tbody = row.parentNode;

  if (tbody.querySelectorAll('tr.text-row').length === 1) {
    return;
  }
  row.remove();
}

function serializeCVSS() {
  if (!validateManualCVSSOverride()) {
    throw new Error("Manual CVSS override is invalid");
  }

  const cvssData = c.get();
  const override = getManualCVSSOverride();
  const score = override || normalizeCVSSOverrideScore(cvssData.score) || cvssData.score;
  return `{${score}}{${cvssData.likelihood}}{${cvssData.impact}}{${cvssData.vector}}{${override}}`;
}

function deserializeCVSS(serialized) {
  const m = serialized.match(/\{([^}]*)\}/g) || [];
  if (m.length < 4) {
    clearManualCVSSOverride();
    applyCVSSScoreDisplay();
    return;
  }

  const score      = m[0].slice(1, -1);
  const likelihood = m[1].slice(1, -1);
  const impact     = m[2].slice(1, -1);
  const vector     = m[3].slice(1, -1);
  const override   = m[4] ? m[4].slice(1, -1) : "";

  c.set({ score, likelihood, impact, vector });
  if (override) {
    setManualCVSSOverride(override);
  } else if (normalizeCVSSOverrideScore(score) && normalizeCVSSOverrideScore(score) !== normalizeCVSSOverrideScore(c.calculate())) {
    setManualCVSSOverride(score);
  } else {
    clearManualCVSSOverride();
  }
  applyCVSSScoreDisplay();
}

function serializeIPsFromTable() {
  const rows = document.querySelectorAll('#textTable tr.text-row');
  const lines = [];

  rows.forEach(row => {
    const textareas = row.querySelectorAll('textarea');
    if (textareas.length < 4) return;

    const ip      = textareas[0].value.trim();
    const port    = textareas[1].value.trim();
    const service = textareas[2].value.trim();
    const version = textareas[3].value.trim();

    // Skip empty rows
    if (!ip && !port && !service && !version) return;

    const line = `{${ip}}{${port}}{${service}}{${version}}`;
    lines.push(line);
  });
  return lines.join('\n');
}

function populateIPsTableFromString(ipsString) {
  const tbody = document.querySelector('#textTable tbody');
  if (!tbody) return;

  const header = tbody.querySelector('tr.text-row-header');
  tbody.querySelectorAll('tr.text-row').forEach(tr => tr.remove());

  const lines = (ipsString || '')
    .split('\n')
    .filter(line => line.trim().length > 0);

  if (lines.length === 0) {
    addRow();
    return;
  }

  // Use a template row once
  const templateRow = tbody.querySelector('tr.text-row') || addRow();

  lines.forEach(line => {
    const matches = line.match(/\{([^}]*)\}/g) || [];
    const [ip, port, service, version] = matches.map(m => m.slice(1, -1));

    const newRow = templateRow.cloneNode(true);
    const textareas = newRow.querySelectorAll('textarea');

    if (textareas.length >= 4) {
      textareas[0].value = ip || '';
      textareas[1].value = port || '';
      textareas[2].value = service || '';
      textareas[3].value = version || '';
    }
    newRow.querySelector('.add-row-btn').onclick = addRow;
    newRow.querySelector('.delete-row-btn').onclick = function () {
      deleteRow(this);
    };

    tbody.appendChild(newRow); // ← inside the loop
  });
  templateRow.querySelector('.delete-row-btn').click();
}

async function createFinding() {
  const input = document.getElementById("new-finding-name");
  const select = document.getElementById("prewrite-select");
  const name = input.value.trim();
  const selectedPrewrite = select ? select.value.trim() : "";

  if (!name) {
    setStatus("Name is required", true);
    return;
  }

  try {
    await fetchJSON("/api/findings", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name })
    });
    setStatus("Finding created");
    input.value = "";
    currentFinding = name;
    await loadFindings();
    await selectFinding(name);

    // If a prewrite is selected (not NONE), pull its content into the new finding
    if (selectedPrewrite) {
      try {
        const pre = await fetchJSON(
          `/api/prewrites/${encodeURIComponent(selectedPrewrite)}`
	);
        const files = pre.files || {}
        FILE_FIELDS.forEach((fname) => {
          const textarea = document.getElementById(fname+'-editor');
          if (textarea && Object.prototype.hasOwnProperty.call(files, fname+'.txt')) {
            textarea.innerHTML = files[fname+'.txt'] || "";
	  }
	});
        // Load CVSS
        deserializeCVSS(files['cvs.txt'] || '');
        // Load IPs
        populateIPsTableFromString(files['ips.txt'] || '');

        // Auto-save after applying changes
        await saveCurrentFinding();
        setStatus("Prewrite applied");
      } catch (e) {
        console.error(e);
        setStatus("Finding created, but failed to apply prewrite", true);
      }
    }
  } catch (e) {
    setStatus(e.message, true);
  }
}

async function selectFinding(name) {
  try {
    const data = await fetchJSON(`/api/findings/${encodeURIComponent(name)}`);
    currentFinding = name;
    document.getElementById("current-finding-title").textContent = name;

    FILE_FIELDS.forEach(fname => {
      const textarea = document.getElementById(fname+'-editor');
      textarea.innerHTML = data.files[fname+'.txt'] || "";
    });
    // Load CVSS
    deserializeCVSS(data.files['cvs.txt'] || '');
    // Load IPs
    populateIPsTableFromString(data.files['ips.txt'] || '');

    await loadImages();

    // update active class
    const listItems = document.querySelectorAll("#finding-list li");
    listItems.forEach(li => {
      li.classList.toggle("active", li.textContent === name);
    });

    setStatus("");
  } catch (e) {
    setStatus(e.message, true);
  }
}

async function saveCurrentFinding() {
  if (!currentFinding) {
    setStatus("No finding selected", true);
    return;
  }
  if (!validateManualCVSSOverride()) {
    return;
  }

  const payload = { files: {} };
  FILE_FIELDS.forEach(fname => {
    const textarea = document.getElementById(fname+'-editor');
    payload.files[fname+'.txt'] = textarea.innerHTML;
  });
  // Save CVSS
  payload.files['cvs.txt'] = serializeCVSS();
  // Save IPs
  payload.files['ips.txt'] = serializeIPsFromTable();
  
  try {
    await fetchJSON(`/api/findings/${encodeURIComponent(currentFinding)}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    setStatus("Saved");
  } catch (e) {
    setStatus(e.message, true);
  }
}
async function saveField(fieldName) {
  if (!currentFinding) {
    setStatus("No finding selected", true);
    return;
  }
  
  let payload;
  const saveBtn = event.target;
  if (!validateManualCVSSOverride()) {
    return;
  }
  
  if (fieldName == 'cvs') {
    payload = { files: { [fieldName+'.txt']: serializeCVSS() } };
  }
  else if (fieldName == 'ips') {
    payload = { files: { [fieldName+'.txt']: serializeIPsFromTable() } };
  } else {
    const textarea = document.getElementById(fieldName+'-editor');

    if (!textarea.innerHTML.trim() && !confirm("Save empty field?")) {
      return;
    }
    
    payload = { files: { [fieldName+'.txt']: textarea.innerHTML } };
  }

  // Visual feedback
  saveBtn.classList.add("saving");
  saveBtn.disabled = true;
  saveBtn.textContent = "L";

  try {

    await fetchJSON(`/api/findings/${encodeURIComponent(currentFinding)}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    saveBtn.textContent = "D";
    setTimeout(() => {
      saveBtn.textContent = "S";
      saveBtn.classList.remove("saving");
      saveBtn.disabled = false;
    }, 800);
  } catch (e) {
    saveBtn.textContent = "E";
    setTimeout(() => {
      saveBtn.textContent = "S";
      saveBtn.classList.remove("saving");
      saveBtn.disabled = false;
    }, 1000);
    setStatus(e.message, true);
  }
}
async function loadImages() {
  if (!currentFinding) return;

  try {
    const data = await fetchJSON(`/api/findings/${encodeURIComponent(currentFinding)}/images`);
    const gallery = document.getElementById("image-gallery");
    gallery.innerHTML = "";

    data.images.forEach(filename => {
      const thumb = document.createElement("div");
      thumb.className = "image-thumbnail";
      
      const img = document.createElement("img");
      img.src = `/api/findings/${encodeURIComponent(currentFinding)}/images/${encodeURIComponent(filename)}`;
      img.alt = filename;
      img.title = filename;

      const label = document.createElement("div");
      label.className = "image-thumbnail-label";
      label.textContent = filename;

      const delBtn = document.createElement("button");
      delBtn.className = "image-delete";
      delBtn.textContent = "x";
      delBtn.title = "Delete image";
      delBtn.addEventListener("click", async () => {
        await deleteImage(filename);
      });
      thumb.appendChild(img);
      thumb.appendChild(label);
      thumb.appendChild(delBtn);
      gallery.appendChild(thumb);
    });
    } catch (e) {
      console.error("Failed to load images:", e);
    }
  }

async function handleImageUpload(files) {
  if (!currentFinding) {
    setStatus("No finding selected", true);
    return;
  }

  try {
    for (let file of files) {
      const formData = new FormData();
      formData.append('image', file);

      const response = await fetch(`/api/findings/${encodeURIComponent(currentFinding)}/images`, {
        method: "POST",
        body: formData
      });

      if (!response.ok) {
        throw new Error(`Failed to upload ${file.name}`);
      }
    }
    await loadImages();
    setStatus("Images uploaded");
  } catch (e) {
    setStatus(e.message, true);
  }
}

window.addEventListener("DOMContentLoaded", () => {
  const overrideEnabled = cvssOverrideEnabled();
  const overrideScoreInput = cvssOverrideScore();

  if (overrideEnabled && overrideScoreInput) {
    overrideEnabled.addEventListener("change", () => {
      overrideScoreInput.disabled = !overrideEnabled.checked;
      if (!overrideEnabled.checked) {
        overrideScoreInput.value = "";
      } else if (!normalizeCVSSOverrideScore(overrideScoreInput.value)) {
        overrideScoreInput.value = normalizeCVSSOverrideScore(c.calculate());
      }
      applyCVSSScoreDisplay();
    });

    overrideScoreInput.addEventListener("input", () => {
      applyCVSSScoreDisplay();
    });

    overrideScoreInput.addEventListener("blur", () => {
      if (!overrideEnabled.checked) return;
      const normalized = normalizeCVSSOverrideScore(overrideScoreInput.value);
      if (normalized) {
        overrideScoreInput.value = normalized;
      }
      applyCVSSScoreDisplay();
    });
  }

  document
    .getElementById("image-picker-close")
    .addEventListener("click", closeImagePicker);

  document
    .getElementById("image-picker-cancel")
    .addEventListener("click", closeImagePicker);

  document
    .getElementById("image-picker-insert")
    .addEventListener("click", insertImageIntoEditor);

  document
    .getElementById("image-picker-modal")
    .addEventListener("click", (e) => {
      if (e.target.id === "image-picker-modal") {
        closeImagePicker();
      }
    });

  document
    .getElementById("create-finding-btn")
    .addEventListener("click", createFinding);

  document
    .getElementById("save-btn")
    .addEventListener("click", saveCurrentFinding);

  document.querySelectorAll(".field-save-btn").forEach(btn => {
    btn.addEventListener("click", (e) => {
      const fieldName = e.target.dataset.field;
      saveField(fieldName);
    });
  });

  // Image upload
  const imageUpload = document.getElementById("image-upload");
  const uploadArea = document.querySelector(".upload-area");

  imageUpload.addEventListener("change", (e) => {
    handleImageUpload(Array.from(e.target.files));
    e.target.value = ""; // Reset for multiple uploads
  });

  // Drag & drop
  uploadArea.addEventListener("dragover", (e) => {
    e.preventDefault();
    uploadArea.classList.add("dragover");
  });

  uploadArea.addEventListener("dragleave", () => {
    uploadArea.classList.remove("dragover");
  });

  uploadArea.addEventListener("drop", (e) => {
    e.preventDefault();
    uploadArea.classList.remove("dragover");
    handleImageUpload(Array.from(e.dataTransfer.files).filter(f => f.type.startsWith("image/")));
  });

  loadFindings().catch((e) => setStatus(e.message, true));
  loadPrewrites().catch((e) => console.error(e));
  clearManualCVSSOverride();
  applyCVSSScoreDisplay();
});

