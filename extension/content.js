(() => {
  const STATE = {
    isTranscribing: false,
  };

  function ensurePanel() {
    let panel = document.getElementById("granola-transcribe-panel");
    if (panel) return panel;

    panel = document.createElement("div");
    panel.id = "granola-transcribe-panel";
    panel.innerHTML = `
      <div class="gp-header">
        <div class="gp-title">Transcription</div>
        <div class="gp-actions">
          <button class="gp-btn" data-action="zoom-out">A-</button>
          <button class="gp-btn" data-action="zoom-in">A+</button>
          <button class="gp-btn" data-action="toggle">Hide</button>
          <button class="gp-btn" data-action="clear">Clear</button>
        </div>
      </div>
      <div class="gp-body"></div>
    `;
    document.documentElement.appendChild(panel);

    // Restore saved geometry
    chrome.storage.local.get(["panelRect", "panelFontScale"], ({ panelRect, panelFontScale }) => {
      if (panelRect) {
        const { top, left, width, height } = panelRect;
        if (typeof top === "number") panel.style.top = `${top}px`;
        if (typeof left === "number") panel.style.left = `${left}px`;
        if (typeof width === "number") panel.style.width = `${width}px`;
        if (typeof height === "number") panel.style.height = `${height}px`;
      }
      const scale = Number(panelFontScale || 1);
      panel.style.fontSize = `${scale * 14}px`;
      panel.setAttribute("data-scale", String(scale));
    });

    // Drag to move by header
    const header = panel.querySelector(".gp-header");
    let dragging = false;
    let startX = 0, startY = 0, startTop = 0, startLeft = 0;
    header.addEventListener("mousedown", (e) => {
      dragging = true;
      startX = e.clientX; startY = e.clientY;
      const rect = panel.getBoundingClientRect();
      startTop = rect.top; startLeft = rect.left;
      e.preventDefault();
    });
    window.addEventListener("mousemove", (e) => {
      if (!dragging) return;
      const dx = e.clientX - startX;
      const dy = e.clientY - startY;
      panel.style.top = `${Math.max(0, startTop + dy)}px`;
      panel.style.left = `${Math.max(0, startLeft + dx)}px`;
    });
    window.addEventListener("mouseup", () => {
      if (!dragging) return;
      dragging = false;
      const rect = panel.getBoundingClientRect();
      chrome.storage.local.set({ panelRect: { top: rect.top, left: rect.left, width: rect.width, height: rect.height } });
    });

    // Persist size after manual CSS resize
    const ro = new ResizeObserver(() => {
      const rect = panel.getBoundingClientRect();
      chrome.storage.local.set({ panelRect: { top: rect.top, left: rect.left, width: rect.width, height: rect.height } });
    });
    ro.observe(panel);

    panel.addEventListener("click", (e) => {
      const target = e.target;
      if (!(target instanceof Element)) return;
      const action = target.getAttribute("data-action");
      if (action === "toggle") {
        const body = panel.querySelector(".gp-body");
        if (body) {
          const isHidden = body.getAttribute("data-hidden") === "1";
          if (isHidden) {
            body.removeAttribute("data-hidden");
            body.style.display = "block";
            target.textContent = "Hide";
          } else {
            body.setAttribute("data-hidden", "1");
            body.style.display = "none";
            target.textContent = "Show";
          }
        }
      } else if (action === "clear") {
        const body = panel.querySelector(".gp-body");
        if (body) body.innerHTML = "";
      } else if (action === "zoom-in") {
        const cur = Number(panel.getAttribute("data-scale") || "1");
        const next = Math.min(1.6, cur + 0.05);
        panel.style.fontSize = `${next * 14}px`;
        panel.setAttribute("data-scale", String(next));
        chrome.storage.local.set({ panelFontScale: next });
      } else if (action === "zoom-out") {
        const cur = Number(panel.getAttribute("data-scale") || "1");
        const next = Math.max(0.8, cur - 0.05);
        panel.style.fontSize = `${next * 14}px`;
        panel.setAttribute("data-scale", String(next));
        chrome.storage.local.set({ panelFontScale: next });
      }
    });
    return panel;
  }

  function appendSentences(text) {
    const panel = ensurePanel();
    const body = panel.querySelector(".gp-body");
    if (!body) return;
    const normalized = text
      .replace(/\s+/g, " ")
      .replace(/\s+([.,!?;:])/g, "$1")
      .replace(/([“"'\(\[{])\s+/g, "$1")
      .replace(/\s+([”"'\)\]}])/g, "$1")
      .trim();
    const sentences = normalized
      .split(/(?<=[.!?])\s+/)
      .map((s) => s.trim())
      .filter(Boolean);
    for (const sentence of sentences) {
      const row = document.createElement("div");
      row.className = "gp-row";
      const p = document.createElement("span");
      p.className = "gp-sentence";
      p.textContent = sentence;
      const btn = document.createElement("button");
      btn.className = "gp-copy";
      btn.textContent = "Copy";
      btn.addEventListener("click", () => navigator.clipboard.writeText(sentence));
      row.appendChild(p);
      row.appendChild(btn);
      body.appendChild(row);
    }
    try { console.log("[input transcript]", sentences.join(" ")); } catch {}
  }

  chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
    if (message?.type === "TRANSCRIPT_SENTENCES") {
      const text = (Array.isArray(message.sentences) ? message.sentences : []).join(" ");
      if (text) appendSentences(text);
      sendResponse?.({ ok: true });
      return true;
    }
  });

  // On load, if transcription is running, ensure panel and request full transcript
  chrome.storage.local.get(["transcribing"], async ({ transcribing }) => {
    if (transcribing) ensurePanel();
    chrome.runtime.sendMessage({ type: "REQUEST_FULL_TRANSCRIPT" }, (resp) => {
      if (!resp) return;
      const { sentences, transcribing: isOn } = resp;
      STATE.isTranscribing = Boolean(isOn);
      if (sentences && sentences.length) {
        appendSentences(sentences.join(" "));
      }
    });
  });
})();


