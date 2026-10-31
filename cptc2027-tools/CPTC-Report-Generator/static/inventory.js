const DISTROS = ["Linux", "Windows"];
const SERVICES = ["FTP", "SSH", "DNS"];

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

function createHost(ip, distro) {
  const nmapList = document.getElementById("host-scroll");
  if (!nmapList) return;

  const block = document.createElement("div");
  block.className = "nmap-block";
  block.id = ip;
  const header = document.createElement("div");
  header.className = "nmap-header";

  const ipTitle = document.createElement("p");
  ipTitle.innerHTML = `<strong>IP:</strong> ${ip}`
  const hostnameTitle = document.createElement("p");
  hostnameTitle.innerHTML = '<strong>Hostname:</strong><input type="text" />'
  const distroTitle = document.createElement("p");
  const distroText = document.createElement("strong");
  distroText.textContent = "Distro:";
  const distroOps = document.createElement("select");
  DISTROS.forEach(dis => {
    const op = new Option(dis, dis.toLowerCase());
    distroOps.add(op);
  });
  distroTitle.appendChild(distroText);
  distroTitle.appendChild(distroOps);
  const osVersionTitle = document.createElement("p");
  osVersionTitle.innerHTML = '<strong>Version:</strong><input type="text" />'
  header.appendChild(ipTitle);
  header.appendChild(hostnameTitle);
  header.appendChild(distroTitle);
  header.appendChild(distroTitle);
  header.appendChild(osVersionTitle);
  block.appendChild(header);

  const systemPlaybook = document.createElement("details");
  systemPlaybook.className = "playbook-list";
  createPlaybook(systemPlaybook, distroOps.value)

  const portHeader = document.createElement("div");
  portHeader.className = "port-header";
  const portTitle = document.createElement("strong");
  portTitle.textContent = "Port";
  const serviceTitle = document.createElement("strong");
  serviceTitle.textContent = "Service";
  const versionTitle = document.createElement("strong");
  versionTitle.textContent = "Version";
  const delBtn = document.createElement("button");
  delBtn.className = "delete-finding-btn";
  delBtn.textContent = 'x';
  portHeader.appendChild(portTitle);
  portHeader.appendChild(serviceTitle);
  portHeader.appendChild(versionTitle);
  portHeader.appendChild(delBtn);
  block.appendChild(portHeader);

  const portList = document.createElement("div");
  portList.className = "port-list";
  portList.id = `${ip}-port`;
  block.appendChild(portList);

  const portBtn = document.createElement("button");
  portBtn.textContent = "Add port";
  block.appendChild(portList);

  const saveBtn = document.createElement("button");
  saveBtn.className = "field-save-btn";
  saveBtn.textContent = 'S';
  block.appendChild(saveBtn);

  nmapList.appendChild(block);
  portBtn.addEventListener("click", (e) => {
    const portNum = prompt("Please enter the port number:");
    createPort(portList, portNum);
  });
  saveBtn.addEventListener("click", async (e) => {
    const data = {
      ip: ip,
      hostname: block.querySelector("p input[type='text']").value,
      distro: block.querySelector("select").value,
      version: block.querySelectorAll("p input[type='text']")[1].value,
      ports: [],
      playbook_steps: []
    };

    block.querySelectorAll(".port-item").forEach(portItem => {
      const portNum = portItem.id.split("-").pop();
      const pMain = portItem.querySelector(".port-main");
      const service = pMain.querySelector("select").value;
      const version = pMain.querySelector("input").value;
      const notes = [];
      portItem.querySelectorAll(".port-note .text-box").forEach(n => notes.push(n.textContent));
      
      data.ports.push({
        number: portNum,
        service: service,
        version: version,
        notes: notes
      });
    });

    block.querySelectorAll(".playbook-step input[type='checkbox']:checked").forEach(cb => {
      const btn = cb.nextElementSibling;
      data.playbook_steps.push(btn.dataset.cmd);
    });

    try {
      await fetch(`/api/inventory/${ip}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data)
      });
      setStatus(`Saved ${ip}`);
    } catch (e) {
      setStatus(e.message, true);
    }
  });
  delBtn.addEventListener("click", async (e) => {
    try {
      await fetch(`/api/inventory/${ip}`, { method: "DELETE" });
      block.remove();
      setStatus(`Deleted ${ip}`);
    } catch (e) {
      setStatus(e.message, true);
    }
  });
  return block;
}

function createPlaybook(el, playbook) {
  if (!playbook || !Array.isArray(playbook)) return;
  for (const step of playbook) {
    const stepEl = document.createElement("div");
    stepEl.className = "playbook-step";
    stepEl.innerHTML = `<input type="checkbox" /> <button data-cmd=${step['cmd']}>${step['text']}</button>`;
    stepEl.querySelector("button").addEventListener("click", (e) => {
      navigator.clipboard.writeText(step['cmd']);
    });

    el.appendChild(stepEl);
  }
}

function createPort(el, portNum) {
  if (!el) return;

  const portItem = document.createElement("div");
  portItem.className = "port-item";
  portItem.id = `${el.id}-${portNum}`;
  const portMain = document.createElement("div");
  portMain.className = "port-main";
  const portN = document.createElement("strong");
  portN.textContent = portNum;
  const portOps = document.createElement("select");
  SERVICES.forEach(svc => {
    const op = new Option(svc, svc.toLowerCase());
    portOps.add(op);
  });
  const portV = document.createElement("input");
  const delBtn = document.createElement("button");
  delBtn.className = "delete-finding-btn";
  delBtn.textContent = 'x';
  portV.type = "text";
  portMain.appendChild(portN);
  portMain.appendChild(portOps);
  portMain.appendChild(portV);
  portMain.appendChild(delBtn);
  portItem.appendChild(portMain);

  const playbook = document.createElement("details");
  playbook.className = "playbook-list";

  const notes = document.createElement("details");
  notes.className = "notes-list";
  notes.innerHTML = '<summary>Notes</summary>';

  const noteBtn = document.createElement("button");
  noteBtn.textContent = "Add notes";
  
  portItem.appendChild(playbook);
  portItem.appendChild(notes);
  portItem.appendChild(noteBtn);
  el.appendChild(portItem);
  
  portOps.addEventListener("change", async (e) => {
    playbook.innerHTML = '<summary>Playbook</summary>';
    const data = await getPlaybookData(portOps.value);
    createPlaybook(playbook, data);
  });
  noteBtn.addEventListener("click", (e) => {
    createNote(notes);
  });
  delBtn.addEventListener("click", (e) => {
    portItem.remove();
  });
  return portItem;
}

function createNote(el, text = null) {
  if (!el) return;
  const noteItem = document.createElement("div");
  noteItem.className = "port-note";
  const delBtn = document.createElement("button");
  delBtn.className = "delete-finding-btn";
  delBtn.textContent = "x";
  const tBox = document.createElement("div");
  tBox.className = "text-box";
  tBox.contentEditable = "true";
  if (text !== null) tBox.textContent = text;
  noteItem.appendChild(delBtn);
  noteItem.appendChild(tBox);
  el.appendChild(noteItem);
  
  delBtn.addEventListener("click", (e) => {
    noteItem.remove();
  });
}

async function loadHosts() {
  const hosts = await fetchJSON("/api/inventory");
  const nmapList = document.getElementById("host-scroll");
  if (!nmapList) return;

  hosts.forEach(host => {
    const block = createHost(host.ip, host.distro);

    // Set hostname
    const hostnameInput = block.querySelector("p input[type='text']");
    if (hostnameInput) hostnameInput.value = host.hostname || "";

    // Set distro
    const distroSelect = block.querySelector("select");
    if (distroSelect) distroSelect.value = (host.distro || "").toLowerCase();

    // Set version
    const versionInput = block.querySelectorAll("p input[type='text']")[1];
    if (versionInput) versionInput.value = host.version || "";

    const portList = document.getElementById(`${host.ip}-port`);
    if (portList && host.ports) {
      host.ports.forEach(port => {
        portItem = createPort(portList, port.number);
        const svcSelect = portItem.querySelector("select");
        const verInput = portItem.querySelector("input");
        if (svcSelect) svcSelect.value = (port.service || "").toLowerCase();
        if (verInput) verInput.value = port.version || "";
            
        // Load notes
        const notesSection = portItem.querySelector(".notes-list");
        if (notesSection && port.notes) {
          port.notes.forEach(noteText => {
            createNote(notesSection, noteText);
          });
        }

        // Trigger playbook load
        const playbookDetails = portItem.querySelector(".playbook-list");
        if (playbookDetails) {
          playbookDetails.innerHTML = '<summary>Playbook</summary>';
          createPlaybook(playbookDetails, getPlaybookData(port.service));
        }
      });
    }
  });
}

async function getPlaybookData(service) {
  if (!service) return [];
  try {
    const data = await fetchJSON(`/api/playbook/${service.toLowerCase()}`);
    return data;
  } catch (e) {
    return [];
  }
}

async function addNmap() {
  const input = document.createElement("input");
  input.type = "file";
  input.accept = ".xml";
  
  input.onchange = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const text = await file.text();
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(text, "text/xml");
    
    const hosts = xmlDoc.querySelectorAll("host");
    hosts.forEach(hostEl => {
      const addrEl = hostEl.querySelector("address");
      const ip = addrEl ? addrEl.getAttribute("addr") : null;
      if (!ip) return;

      const hostNameEl = hostEl.querySelector("hostname");
      const hostname = hostNameEl ? hostNameEl.textContent : "";

      // OS detection
      const osEl = hostEl.querySelector("os");
      let distro = "Linux"; // Default
      let version = "";
      if (osEl) {
        const osMatch = osEl.textContent.toLowerCase();
        if (osMatch.includes("windows")) distro = "Windows";
        const osService = osEl.querySelector("osservice");
        if (osService) version = osService.textContent;
      }

      // Check if host already exists in DOM
      let block = document.getElementById(ip);
      if (!block) block = createHost(ip, distro);

      // Update hostname/distro if needed
      const hInput = block.querySelector("p input[type='text']");
      if (hInput) hInput.value = hostname;
      const dSelect = block.querySelector("select");
      if (dSelect) dSelect.value = distro.toLowerCase();

      // Ports
      const ports = hostEl.querySelectorAll("port");
      const portList = document.getElementById(`${ip}-port`);
      ports.forEach(portEl => {
        const pNum = portEl.getAttribute("portid");
        
        // Check if port already exists
        let portItem = document.getElementById(`${ip}-port-${pNum}`);
        if (!portItem) portItem = createPort(portList, pNum);

        const serviceEl = portEl.querySelector("service");
        const name = serviceEl ? serviceEl.getAttribute("name") : "";
        const product = serviceEl ? serviceEl.getAttribute("product") : "";
        const version_port = serviceEl ? serviceEl.getAttribute("version") : "";

        const pMain = portItem.querySelector(".port-main");
        const pSvc = pMain.querySelector("select");
        const pVer = pMain.querySelector("input");
        if (pSvc) pSvc.value = (name || "").toLowerCase();
        if (pVer) pVer.value = (product + (product && version_port ? " " : "") + version_port).trim();
      });
    });
  };

  input.click();
}

window.addEventListener("DOMContentLoaded", () => {
  document
    .getElementById("nmap-btn")
    .addEventListener("click", addNmap);

  loadHosts().catch((e) => setStatus(e.message, true));
});

