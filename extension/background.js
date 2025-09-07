let isTranscribing = false;
let sentencesStore = [];

async function ensureOffscreen() {
  const has = await chrome.offscreen.hasDocument?.();
  if (!has) {
    const reasons = [];
    const R = chrome.offscreen?.Reason;
    if (R && R.USER_MEDIA) reasons.push(R.USER_MEDIA); else reasons.push("USER_MEDIA");
    if (R && R.BLOBS) reasons.push(R.BLOBS); else reasons.push("BLOBS");
    await chrome.offscreen.createDocument({
      url: "offscreen.html",
      reasons,
      justification: "Microphone capture and chunk upload for transcription",
    });
  }
  // Wait for readiness
  await new Promise((resolve) => {
    let settled = false;
    const done = () => { if (!settled) { settled = true; resolve(); } };
    const listener = (msg, _sender, sendResponse) => {
      if (msg?.type === "OFFSCREEN_READY") { sendResponse?.({ ok: true }); chrome.runtime.onMessage.removeListener(listener); done(); }
    };
    chrome.runtime.onMessage.addListener(listener);
    // ping in case it's already ready
    chrome.runtime.sendMessage({ type: "OFFSCREEN_PING" }, () => { setTimeout(done, 100); });
    setTimeout(() => { chrome.runtime.onMessage.removeListener(listener); done(); }, 1500);
  });
}

async function broadcastToTabs(message) {
  const tabs = await chrome.tabs.query({});
  await Promise.all(
    tabs.map((tab) => tab.id && chrome.tabs.sendMessage(tab.id, message).catch(() => {})),
  );
}

async function postToServer(sentences) {
  try {
    await fetch("http://localhost:3000/transcript/append", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ sentences }),
    });
  } catch {}
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "START_TRANSCRIPTION") {
    isTranscribing = true;
    chrome.storage.local.set({ transcribing: true });
    ensureOffscreen().then(() => chrome.runtime.sendMessage({ type: "OFFSCREEN_START" }));
    sendResponse?.({ ok: true });
    return true;
  }

  if (message?.type === "STOP_TRANSCRIPTION") {
    isTranscribing = false;
    chrome.storage.local.set({ transcribing: false });
    chrome.runtime.sendMessage({ type: "OFFSCREEN_STOP" });
    // Optionally close offscreen
    (async () => {
      try {
        const has = await chrome.offscreen.hasDocument?.();
        if (has) await chrome.offscreen.closeDocument?.();
      } catch {}
    })();
    sendResponse?.({ ok: true });
    return true;
  }

  if (message?.type === "TRANSCRIPT_SENTENCES") {
    const sentences = Array.isArray(message.sentences) ? message.sentences : [];
    if (sentences.length) {
      sentencesStore.push(...sentences);
      broadcastToTabs({ type: "TRANSCRIPT_SENTENCES", sentences });
      postToServer(sentences);
    }
    sendResponse?.({ ok: true });
    return true;
  }

  if (message?.type === "TRANSCRIBE_ERROR") {
    const err = String(message.error || "");
    // If mic permission was dismissed/blocked, open a permissions helper page
    if (/NotAllowedError/i.test(err)) {
      chrome.tabs.create({ url: chrome.runtime.getURL("permissions.html"), active: true });
    }
    sendResponse?.({ ok: true });
    return true;
  }

  if (message?.type === "REQUEST_FULL_TRANSCRIPT") {
    sendResponse?.({ sentences: sentencesStore.slice(), transcribing: isTranscribing });
    return true;
  }

  if (message?.type === "EXPORT_REQUEST") {
    const data = (sentencesStore.join("\n")) || "(no transcription)";
    const dataUrl = `data:text/plain;charset=utf-8,${encodeURIComponent(data)}`;
    chrome.downloads.download({
      url: dataUrl,
      filename: `transcript-${Date.now()}.txt`,
      saveAs: true,
    });
    sendResponse?.({ ok: true });
    return true;
  }

  if (message?.type === "EXPORT_GOOGLE_DOCS") {
    (async () => {
      try {
        const text = (sentencesStore.join("\n")) || "";
        const tab = await chrome.tabs.create({ url: "https://docs.new", active: true });
        // Retry a few times while Docs initializes
        const tries = [1500, 3000, 5000];
        tries.forEach((ms) => {
          setTimeout(async () => {
            try { await chrome.tabs.sendMessage(tab.id, { type: "DOCS_POPULATE", text }); } catch {}
          }, ms);
        });
      } catch {}
    })();
    sendResponse?.({ ok: true });
    return true;
  }
});


