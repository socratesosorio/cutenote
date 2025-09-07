// Reuse the same panel UI logic as content script, but in an override new tab page
function ensurePanel() {
  let panel = document.getElementById("granola-transcribe-panel");
  if (panel) return panel;
  panel = document.createElement("div");
  panel.id = "granola-transcribe-panel";
  panel.innerHTML = `
    <div class="gp-header">
      <div class="gp-title">Transcription</div>
      <div class="gp-actions">
        <button class="gp-btn" data-action="toggle">Hide</button>
        <button class="gp-btn" data-action="clear">Clear</button>
      </div>
    </div>
    <div class="gp-body"></div>
  `;
  document.body.appendChild(panel);
  panel.addEventListener("click", (e) => {
    const target = e.target;
    if (!(target instanceof Element)) return;
    const action = target.getAttribute("data-action");
    if (action === "toggle") {
      const body = panel.querySelector(".gp-body");
      if (!body) return;
      const hidden = body.getAttribute("data-hidden") === "1";
      if (hidden) {
        body.removeAttribute("data-hidden");
        body.style.display = "block";
        target.textContent = "Hide";
      } else {
        body.setAttribute("data-hidden", "1");
        body.style.display = "none";
        target.textContent = "Show";
      }
    } else if (action === "clear") {
      const body = panel.querySelector(".gp-body");
      if (body) body.innerHTML = "";
    }
  });
  return panel;
}

function appendSentences(text) {
  const panel = ensurePanel();
  const body = panel.querySelector(".gp-body");
  if (!body) return;
  const sentences = text.split(/(?<=[.!?])\s+/).map((s) => s.trim()).filter(Boolean);
  for (const s of sentences) {
    const p = document.createElement("p");
    p.className = "gp-sentence";
    p.textContent = s;
    body.appendChild(p);
  }
}

// Receive live transcript lines from background
chrome.runtime.onMessage.addListener((message) => {
  if (message?.type === "TRANSCRIPT_SENTENCES") {
    const text = (Array.isArray(message.sentences) ? message.sentences : []).join(" ");
    if (text) appendSentences(text);
  }
});

// Populate existing transcript
chrome.runtime.sendMessage({ type: "REQUEST_FULL_TRANSCRIPT" }, (resp) => {
  if (!resp) return;
  const { sentences } = resp;
  if (sentences?.length) appendSentences(sentences.join(" "));
});


