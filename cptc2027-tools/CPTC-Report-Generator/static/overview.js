const FILE_FIELDS = [
  "team-name",
  "team-email",
  "team-phone",
  "client-name",
  "start-time",
  "end-time",
  "report-time",
  "short-scope",
  "executive",
  "rationale",
  "goals",
  "ai-workflow",
  "ai-efficacy",
  "scope",
  "strengths",
  "recommendations"
];

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

function setStatus(msg, isError = false) {
  const el = document.getElementById("status");
  el.textContent = msg || "";
  el.style.color = isError ? "red" : "#555";
}

async function saveField(fieldName) {
  let payload;
  const saveBtn = event.target;

  const textarea = document.getElementById(fieldName+'-editor');
  if (!textarea.innerHTML.trim() && !confirm("Save empty field?")) {
    return;
  }
  payload = { files: { [fieldName+'.txt']: textarea.innerHTML } };

  // Visual feedback
  saveBtn.classList.add("saving");
  saveBtn.disabled = true;
  saveBtn.textContent = "L";

  try {
    await fetchJSON('/api/overviews', {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });

    // Visual feedback
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

async function saveOverviews() {
  const payload = { files: {} };
  FILE_FIELDS.forEach(fname => {
    const textarea = document.getElementById(fname+'-editor');
    payload.files[fname+'.txt'] = textarea.innerHTML;
  });

  try {
    await fetchJSON('/api/overviews', {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    setStatus("Saved");
  } catch (e) {
    setStatus(e.message, true);
  }
}

async function loadOverview() {
  try {
    const data = await fetchJSON('/api/overviews');
    FILE_FIELDS.forEach(fname => {
      const textarea = document.getElementById(fname+'-editor');
      textarea.innerHTML = data.files[fname+'.txt'] || "";
    });
    setStatus("");
  } catch (e) {
    setStatus(e.message, true);
  }
}

window.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".field-save-btn").forEach(btn => {
    btn.addEventListener("click", (e) => {
      const fieldName = e.target.dataset.field;
      saveField(fieldName);
    });
  });

  document
    .getElementById("save-btn")
    .addEventListener("click", saveOverviews);

  loadOverview().catch((e) => setStatus(e.message, true));
});
