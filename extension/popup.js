const startBtn = document.getElementById("startBtn");
const stopBtn = document.getElementById("stopBtn");
const statusEl = document.getElementById("status");
const micEl = document.getElementById("mic");
const logEl = document.getElementById("log");

function setStatus(text) {
  statusEl.textContent = text;
}

startBtn.addEventListener("click", async () => {
  startBtn.disabled = true;
  stopBtn.disabled = false;
  setStatus("Transcribing...");
  if (micEl) micEl.classList.add("on");
  try {
    // Prime mic permission while popup is visible
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    stream.getTracks().forEach((t) => t.stop());
  } catch (e) {
    console.error("User media permission denied:", e);
  }
  await chrome.runtime.sendMessage({ type: "START_TRANSCRIPTION" });
});

stopBtn.addEventListener("click", async () => {
  startBtn.disabled = false;
  stopBtn.disabled = true;
  setStatus("Idle");
  if (micEl) micEl.classList.remove("on");
  await chrome.runtime.sendMessage({ type: "STOP_TRANSCRIPTION" });
});

// Initialize state based on storage
chrome.storage.local.get(["transcribing"], ({ transcribing }) => {
  const isOn = Boolean(transcribing);
  startBtn.disabled = isOn;
  stopBtn.disabled = !isOn;
  setStatus(isOn ? "Transcribing..." : "Idle");
  if (micEl) micEl.classList.toggle("on", isOn);
});

// Render helper
function appendLines(lines) {
  const list = Array.isArray(lines) ? lines : [String(lines || "")];
  for (const line of list) {
    const p = document.createElement("div");
    p.textContent = line;
    logEl.appendChild(p);
  }
  logEl.scrollTop = logEl.scrollHeight;
}

// Receive live transcript lines from background
chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === "TRANSCRIPT_SENTENCES") {
    const text = (Array.isArray(message.sentences) ? message.sentences : []).join(" ");
    if (text) appendLines(text);
  }
  if (message?.type === "TRANSCRIBE_STATE") {
    const on = Boolean(message.on);
    if (micEl) micEl.classList.toggle("on", on);
    setStatus(on ? "Transcribing..." : "Idle");
  }
});

// Populate current transcript
chrome.runtime.sendMessage({ type: "REQUEST_FULL_TRANSCRIPT" }, (resp) => {
  if (!resp) return;
  const { sentences } = resp;
  if (sentences?.length) appendLines(sentences);
});
