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

async function addGroup() {
  const groupName = prompt("Please enter the group name:");

  if (groupName === null || groupName.trim() === "") {
    setStatus('Group Name not provided');
    return;
  }
  const groupId = groupName.replaceAll(' ', '-')

  try {
    await fetchJSON(`/api/fileshare/${groupId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: groupName })
    });
    return createGroup(groupName);
  } catch (e) {
    setStatus(e.message, true);
    return null;
  }
}

function createGroup(groupName) {
  const scroll = document.getElementById('fileshare-groups');
  if (!scroll) return;

  const groupId = groupName.replaceAll(' ', '-');
  const gBox = document.createElement('div');
  gBox.className = 'group-box';
  gBox.id = groupId;
  const gHead = document.createElement('div');
  gHead.className = 'group-header';
  const gTitle = document.createElement('h3');
  gTitle.textContent = groupName;
  const delBtn = document.createElement('button');
  delBtn.className = 'delete-finding-btn';
  delBtn.textContent = 'x';
  gHead.appendChild(gTitle);
  gHead.appendChild(delBtn);

  gBox.appendChild(gHead);
  const gList = document.createElement('div');
  gList.className = 'group-list';
  gList.id = `${groupId}-list`;
  gBox.appendChild(gList);

  const addBtn = document.createElement('button');
  addBtn.textContent = 'Upload file';
  gBox.appendChild(addBtn);
  scroll.appendChild(gBox);

  delBtn.addEventListener("click", (e) => {
    deleteGroup(groupName);
    gBox.remove();
  });
  addBtn.addEventListener("click", (e) => {
    const entry = addFile(groupName);
    gList.appendChild(entry);
  });
}

async function addFile(groupId) {
  const input = document.createElement('input');
  input.type = 'file'
  input.onchange = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);

    try {
      const res = await fetchJSON(`/api/fileshare/${groupId}/${file.name}`, {
        method: 'POST',
        body: formData,
      });
      createFile(groupId, res.filename);
    } catch (e) {
      setStatus(e.message, true);
    }
  };
  input.click();
}

function createFile(groupId, fileId) {
  const gList = document.getElementById(`${groupId}-list`)
  if (!gList) return;

  const listItem = document.createElement('div');
  listItem.className = 'group-item';
  const itemName = document.createElement('div');
  itemName.textContent = fileId;
  listItem.appendChild(itemName);

  const itemBtns = document.createElement('div');
  itemBtns.className = 'group-item';
  const dwnLink = document.createElement('a');
  dwnLink.className = 'download-btn';
  dwnLink.innerHTML = '&#x2B73;';
  dwnLink.href = `/api/fileshare/${groupId}/${fileId}`;
  dwnLink.download = fileId;

  const delBtn = document.createElement('button');
  delBtn.className = 'delete-finding-btn';
  delBtn.textContent = 'x';

  itemBtns.appendChild(dwnLink);
  itemBtns.appendChild(delBtn);
  listItem.appendChild(itemBtns);
  gList.appendChild(listItem);

  delBtn.addEventListener("click", (e) => {
    deleteFile(groupId, fileId);
    listItem.remove();
  });
}

async function deleteFile(groupId, fileId) {
  try {
    await fetchJSON(`/api/fileshare/${groupId}/${fileId}`, { method: 'DELETE' });
    setStatus(`Deleted file ${fileId}`);
  } catch (e) {
    setStatus(e.message, true);
  }
}

async function deleteGroup(groupId) {
  try {
    await fetchJSON(`/api/fileshare/${groupId}`, { method: 'DELETE' });
    setStatus(`Deleted group ${groupId}`);
  } catch (e) {
    setStatus(e.message, true);
  }
}

async function loadAllFiles() {
  const scroll = document.getElementById('fileshare-groups');
  if (!scroll) return;
  scroll.innerHTML = '';

  const fileData = await fetchJSON('/api/fileshare', { method: 'GET' });
  for (const [group, files] of Object.entries(fileData || {})) {
    createGroup(group);
    const groupId = group.replaceAll(' ', '-')
    for (const file of files) {
      createFile(groupId, file);
    }
  }

  setStatus("Loaded all files");
}

window.addEventListener("DOMContentLoaded", () => {
  document
    .getElementById("create-group-btn")
    .addEventListener("click", addGroup);

  loadAllFiles().catch((e) => setStatus(e.message, true));
});

