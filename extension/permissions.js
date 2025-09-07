const btn = document.getElementById("grant");
const statusEl = document.getElementById("status");

function setStatus(msg, ok) {
  statusEl.textContent = msg;
  statusEl.className = ok ? "hint ok" : "hint";
}

btn.addEventListener("click", async () => {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    stream.getTracks().forEach((t) => t.stop());
    setStatus("Microphone granted. You can close this tab.", true);
    // Try to start offscreen immediately
    await chrome.runtime.sendMessage({ type: "START_TRANSCRIPTION" });
  } catch (e) {
    console.error(e);
    setStatus("Permission failed or dismissed. Try again and accept the prompt.");
  }
});


