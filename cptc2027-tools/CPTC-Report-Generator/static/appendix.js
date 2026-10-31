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

function enrichEditor(btnBar) {
  const targetId = btnBar.dataset.target;
  const editor = document.getElementById(targetId);
  if (!editor) return;

  btnBar.addEventListener('click', (e) => {
    const btn = e.target.closest('button');
    if (!btn) return;

    const cmd = btn.dataset.cmd;
    const action = btn.dataset.action;
    if (cmd) {
      editor.focus();
      document.execCommand(cmd, false, null);
    } else if (action) {
      const selection = window.getSelection();
      const range = selection.rangeCount ? selection.getRangeAt(0) : null;

      if (!range && action !== 'image') return;

      if (action === 'inline-code') {
        const span = document.createElement('code');
        span.textContent = selection.toString();
        range.deleteContents();
        range.insertNode(span);
      }

      if (action === 'code-block') {
        const pre = document.createElement('pre');
        const code = document.createElement('code');
        code.textContent = selection.toString() || 'your code here';
        pre.appendChild(code);
        range.deleteContents();
        range.insertNode(pre);
      }

      if (action === 'link') {
        const url = prompt('Enter URL:');
        if (url) {
          document.execCommand('createLink', false, url);
        }
      }

      if (action === 'image') {
        if (typeof window.openImagePicker === 'function') {
          window.openImagePicker(targetId, range ? range.cloneRange() : null);
        }
      }
    } else {
      return;
    }
  });
}

function addTool() {
  const toolName = prompt("Please enter the tool name:");
  
  if (toolName === null || toolName.trim() === "") {
    setStatus('Tool Name not Provided');
    return;
  }
  return createTool(toolName);
}

function createTool(toolName) {
  const toolId = toolName.replaceAll(' ', '-').toLowerCase();
  const toolList = document.querySelector('#tool-list');
  const newTool = document.createElement('div');
  newTool.className = 'field-section';
  newTool.id = toolId;

  const tName = document.createElement('div');
  tName.className = 'field-header';

  const delBtn = document.createElement('button');
  delBtn.className = 'delete-finding-btn del-tool-btn';
  delBtn.textContent = 'x';

  tName.appendChild(delBtn);

  const fields = ['Tool Name', 'Version', 'Link'];
  for (const field of fields) {
    const sField = document.createElement('div');
    sField.className = 'sub-field';
    const fieldName = document.createElement('h3');
    fieldName.textContent = field;
    const tBox = document.createElement('div');
    tBox.className = 'text-box';
    tBox.contentEditable = true;
    sField.appendChild(fieldName);
    sField.appendChild(tBox);
    tName.appendChild(sField);
  }

  const saveBtn = document.createElement('button');
  saveBtn.className = 'field-save-btn save-tool-btn';
  saveBtn.textContent = 'S';
  tName.appendChild(saveBtn);
  newTool.appendChild(tName);

  const sField = document.createElement('div');
  sField.className = 'sub-field second-row';
  const fieldName = document.createElement('h3');
  fieldName.textContent = 'Description';
  const tBox = document.createElement('div');
  tBox.className = 'text-box';
  tBox.contentEditable = true;
  sField.appendChild(fieldName);
  sField.appendChild(tBox);
  newTool.appendChild(sField);
  
  toolList.appendChild(newTool);
  delBtn.addEventListener("click", (e) => {
    deleteTool(toolId).catch((e) => setStatus(e.message, true));
    newTool.remove();
  });
  saveBtn.addEventListener("click", (e) => {
    saveTool(toolId).catch((e) => setStatus(e.message, true));
  });
  setStatus('Tool Added');
  return newTool;
}

function addAppendix() {
  const appendixName = prompt("Please enter the appendix name:");

  if (appendixName === null || appendixName.trim() === "") {
    setStatus('Appendix Name not Provided');
    return;
  }
  return createAppendix(appendixName)
}

function createAppendix(appendixName) {
  const appId = appendixName.replaceAll(' ', '-').toLowerCase();
  const appendixList = document.querySelector('#appendix-list');
  const section = document.createElement('div');
  section.className = 'field-section';
  section.id = appId;
  const header = document.createElement('div');
  header.className = 'field-header';
  const delBlock = document.createElement('div');
  delBlock.className = 'del-block';
  const delBtn = document.createElement('button');
  delBtn.className = 'delete-finding-btn del-appendix-btn';
  delBtn.textContent = 'x';
  const aName = document.createElement('h3');
  aName.textContent = appendixName;
  delBlock.appendChild(delBtn);
  delBlock.appendChild(aName);
  header.appendChild(delBlock);
  
  const btns = { CMDbold: '<strong>B</strong>', CMDitalic: '<em>I</em>', CMDinsertUnorderedList: '&bull; List', CMDinsertOrderedList: '1. List', 'inline-code': '`Code`', 'code-block': '( Code )', link: 'Link', image: 'Image'};

  const toolbar = document.createElement('div');
  toolbar.className = 'toolbar';
  toolbar.dataset.target = appId;
  for (const [cmd, content] of Object.entries(btns)) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.innerHTML = content;
    if (cmd.substring(0, 3) == 'CMD') {
      btn.dataset.cmd = cmd.substring(3);
    } else {
      btn.dataset.action = cmd
    }
    toolbar.appendChild(btn);
  }
  header.appendChild(toolbar);

  const saveBtn = document.createElement('button');
  saveBtn.className = 'field-save-btn save-appendix-btn';
  saveBtn.textContent = 'S';
  header.appendChild(saveBtn);
  section.appendChild(header);
  
  const tBox = document.createElement('div');
  tBox.id = appId;
  tBox.className = 'text-box';
  tBox.contentEditable = true;
  section.appendChild(tBox);

  appendixList.appendChild(section);
  enrichEditor(toolbar);
  delBtn.addEventListener("click", (e) => {
    deleteAppendix(appId).catch((e) => setStatus(e.message, true));
    section.remove();
  });
  saveBtn.addEventListener("click", (e) => {
    saveAppendix(appId).catch((e) => setStatus(e.message, true));
  });
  setStatus('Appendix Added');
  return section;
}

async function saveTool(toolId) {
  const tool = document.getElementById(toolId);
  const saveBtn = event.target;
  if (!tool) {
    setStatus(`Tool ${toolId} not found`, true);
    return;
  }
  // Visual feedback
  saveBtn.classList.add("saving");
  saveBtn.disabled = true;
  saveBtn.textContent = "L";

  const boxes = tool.querySelectorAll('.text-box');
  const data = {
    name: boxes[0]?.textContent || "",
    version: boxes[1]?.textContent || "",
    link: boxes[2]?.textContent || "",
    description: boxes[3]?.textContent || "",
  };

  try {
    await fetchJSON('/api/appendix/tools', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ files: { [toolId]: data } })
    });

    // Visual feedback
    saveBtn.textContent = "D";
    setStatus(`Saved Tool ${boxes[0]?.textContent || ""}`);
  } catch (e) {
    saveBtn.textContent = "E";
    setStatus(e.message, true);
  }
  setTimeout(() => {
    saveBtn.textContent = "S";
    saveBtn.classList.remove("saving");
    saveBtn.disabled = false;
  }, 1000);
}

async function saveAppendix(appId) {
  const section = document.getElementById(appId);
  const saveBtn = event.target;
  if (!section) {
    setStatus(`Appendix ${appId} not found`, true);
    return;
  }
  // Visual feedback
  saveBtn.classList.add("saving");
  saveBtn.disabled = true;
  saveBtn.textContent = "L";

  const nameEl = section.querySelector('.del-block h3');
  const tBox = section.querySelector('.text-box');
  const name = nameEl ? nameEl.textContent : "";
  const content = tBox ? tBox.innerHTML : "";
  const finalContent = `${name}\n${content}`;

  try {
    await fetchJSON('/api/appendix/entry', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ files: { [appId]: finalContent } })
    });
    // Visual feedback
    saveBtn.textContent = "D";
    setStatus(`Saved Appendix ${name}`);
  } catch (e) {
    saveBtn.textContent = "E";
    setStatus(e.message, true);
  }
  setTimeout(() => {
    saveBtn.textContent = "S";
    saveBtn.classList.remove("saving");
    saveBtn.disabled = false;
  }, 1000);
}

async function deleteTool(toolId) {
  await fetchJSON(`/api/appendix/tools/${toolId}`, { method: 'DELETE' });
  setStatus(`Delete Tool ${toolName}`);
}

async function deleteAppendix(appId) {
  await fetchJSON(`/api/appendix/entry/${appId}`, { method: 'DELETE' });
  setStatus(`Delete Appendix ${appName}`);
}

async function saveAllAppendix() {
  const toolFiles = {};
  document.querySelectorAll('#tool-list .field-section').forEach(sec => {
    const id = sec.id;
    if (id) {
      const boxes = sec.querySelectorAll('.text-box');
      toolFiles[id] = {
        name: boxes[0]?.textContent || "",
        version: boxes[1]?.textContent || "",
        link: boxes[2]?.textContent || "",
        description: boxes[3]?.textContent || "",
      };
    }
  });

  const appendixFiles = {};
  document.querySelectorAll('#appendix-list .field-section').forEach(sec => {
    const id = sec.idd;
    if (id) {
      const nameEl = sec.querySelector('.del-block h3');
      const tBox = sec.querySelector('.text-box');
      const name = nameEl ? nameEl.textContent : "";
      const content = tBox ? tBox.innerHTML : "";
      appendidxFiles[id] = `${name}\n${content}`;
    }
  });

  await fetchJSON('/api/appendix/tools', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ files: toolFiles })
  });
  await fetchJSON('/api/appendix/entry', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ files: appendixFiles })
  });
  setStatus('Save all appendix data');
}

async function loadAllAppendix() {
  const toolsData = await fetchJSON('/api/appendix/tools');
  for (const [id, values] of Object.entries(toolsData || {})) {
    const tool = createTool(values['name']);
    const boxes = tool.querySelectorAll('.text-box');
    if (boxes[0]) boxes[0].textContent = values['name'];
    if (boxes[1]) boxes[1].textContent = values['version'];
    if (boxes[2]) boxes[2].textContent = values['link'];
    if (boxes[3]) boxes[3].textContent = values['description'];
  }

  const appendixData = await fetchJSON('/api/appendix/entry');
  for (const [id, content] of Object.entries(appendixData)) {
    const newLineIdx = content.indexOf('\n');
    let name, body;
    if (newLineIdx !== -1) {
      name = content.substring(0, newLineIdx);
      body = content.substring(newLineIdx+1);
    } else {
      name = content;
      body = "";
    }

    const app = createAppendix(name);
    const tBox = app.querySelector('.text-box');
    if (tBox) tBox.innerHTML = body;
  }
  setStatus('Load All Appendix');
}

window.addEventListener("DOMContentLoaded", () => {
  document
    .getElementById("add-tool-btn")
    .addEventListener("click", addTool);

  document
    .getElementById("save-btn")
    .addEventListener("click", saveAllAppendix);

  document
    .getElementById("add-appendix-btn")
    .addEventListener("click", addAppendix);

  document.querySelectorAll(".save-tool-btn").forEach(btn => {
    btn.addEventListener("click", (e) => {
      const fieldName = e.target.dataset.field;
      saveTool(fieldName);
    });
  });

  document.querySelectorAll(".save-appendix-btn").forEach(btn => {
    btn.addEventListener("click", (e) => {
      const fieldName = e.target.dataset.field;
      saveAppendix(fieldName);
    });
  });

  loadAllAppendix().catch((e) => setStatus(e.message, true));
});

