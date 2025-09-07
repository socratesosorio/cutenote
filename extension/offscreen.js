const STATE = {
  running: false,
  micStream: null,
  pc: null,
  dc: null,
  partial: "",
  sawInputTranscript: false,
};

function normalizeTranscriptSpacing(text) {
  if (!text) return "";
  let t = text;
  // Collapse multiple spaces
  t = t.replace(/\s+/g, " ");
  // Remove space before punctuation
  t = t.replace(/\s+([.,!?;:])/g, "$1");
  // Remove space after opening brackets/quotes and before closing
  t = t.replace(/([“"'\(\[{])\s+/g, "$1");
  t = t.replace(/\s+([”"'\)\]}])/g, "$1");
  return t.trim();
}

function waitForIceGatheringComplete(pc, timeoutMs = 3000) {
  if (pc.iceGatheringState === "complete") return Promise.resolve();
  return new Promise((resolve) => {
    let done = false;
    const finish = () => { if (!done) { done = true; resolve(); } };
    const onChange = () => {
      if (pc.iceGatheringState === "complete") {
        pc.removeEventListener("icegatheringstatechange", onChange);
        finish();
      }
    };
    pc.addEventListener("icegatheringstatechange", onChange);
    setTimeout(() => {
      pc.removeEventListener("icegatheringstatechange", onChange);
      finish();
    }, timeoutMs);
  });
}

function extractDeltaText(event) {
  try {
    if (!event || typeof event !== "object") return "";
    if (event.type === "response.delta" && event.delta && event.delta.type === "output_text.delta") {
      return event.delta.text || "";
    }
    if (event.type === "response.output_text.delta" && typeof event.text === "string") {
      return event.text;
    }
    // Fallback: if model emits audio output with transcript, capture it
    if (event.type === "response.output_audio_transcript.delta" && typeof event.delta === "string") {
      return event.delta;
    }
    // GA input transcription stream
    if (event.type === "input_audio_transcript.delta" && typeof event.delta === "string") {
      return event.delta;
    }
    if (event.type === "input_audio_transcript.done" && typeof event.transcript === "string") {
      return event.transcript;
    }
    // Older beta name
    if (event.type === "input_audio_transcription.completed" && typeof event.transcript === "string") {
      return event.transcript;
    }
  } catch {}
  return "";
}

function flushPartial() {
  const text = normalizeTranscriptSpacing(STATE.partial);
  if (!text) return;
  const sentences = text
    .split(/(?<=[.!?])\s+/)
    .map((s) => s.trim())
    .filter(Boolean);
  if (sentences.length) {
    chrome.runtime.sendMessage({ type: "TRANSCRIPT_SENTENCES", sentences });
  }
  STATE.partial = "";
}

async function startTranscription() {
  if (STATE.running) return;
  STATE.running = true;

  try {
    STATE.micStream = await navigator.mediaDevices.getUserMedia({ audio: true });
  } catch (e) {
    console.error("Offscreen mic permission error:", e);
    chrome.runtime.sendMessage({ type: "TRANSCRIBE_ERROR", error: String(e) });
    STATE.running = false;
    return;
  }

  const pc = new RTCPeerConnection();
  STATE.pc = pc;

  // Add mic track
  const [track] = STATE.micStream.getAudioTracks();
  // Ensure we negotiate audio both ways (some models expect recv)
  try { pc.addTransceiver("audio", { direction: "sendrecv" }); } catch {}
  if (track) pc.addTrack(track, STATE.micStream);

  // Attach remote audio (parity with console; harmless for transcription-only)
  try {
    const audio = new Audio();
    audio.autoplay = true;
    audio.muted = true;
    audio.volume = 0;
    audio.style.display = "none";
    pc.ontrack = (e) => { audio.srcObject = e.streams[0]; };
  } catch {}

  const dc = pc.createDataChannel("oai-events");
  STATE.dc = dc;

  dc.addEventListener("open", () => {
    // Minimal session.update per docs: set instructions only
    try {
      dc.send(
        JSON.stringify({
          type: "session.update",
          session: {
            type: "realtime",
            instructions:
              "You are a transcription passthrough. Repeat the user's speech verbatim as plain text, same language. Do not add or change words, no greetings or filler. Output nothing when there is no speech.",
          },
        }),
      );
      dc.send(
        JSON.stringify({
          type: "response.create",
          response: {
            modalities: ["text"],
            instructions: "Repeat user's speech verbatim as plain text only.",
          },
        }),
      );
    } catch {}
  });

  dc.addEventListener("message", (e) => {
    try {
      const evt = JSON.parse(e.data);
      // Accumulate text deltas; log only when a response finishes
      const text = extractDeltaText(evt);
      if (text) {
        const prev = STATE.partial;
        const last = prev.slice(-1);
        const first = text.charAt(0);
        const needsSpace = prev && /\w|[\p{L}\p{N}]/u.test(last) && /\w|[\p{L}\p{N}]/u.test(first);
        STATE.partial += (needsSpace ? " " : "") + text;
      }
      // If model emits a final transcript payload for output audio, flush immediately
      if (evt.type === "response.output_audio_transcript.done" && typeof evt.transcript === "string") {
        if (!STATE.partial) STATE.partial = evt.transcript;
        try { console.log("[input transcript]", STATE.partial); } catch {}
        flushPartial();
      }
      // Prefer GA input transcripts when available
      if (evt.type === "input_audio_transcript.delta") {
        STATE.sawInputTranscript = true;
      }
      if (evt.type === "input_audio_transcript.done" || evt.type === "input_audio_transcription.completed") {
        STATE.sawInputTranscript = true;
        if (!STATE.partial && typeof evt.transcript === "string") {
          STATE.partial = evt.transcript;
        }
        try { console.log("[input transcript]", STATE.partial); } catch {}
        flushPartial();
        return;
      }
      if (evt.type === "response.done" || evt.type === "response.completed") {
        // Only use output-text fallback if GA input transcripts are not available
        if (STATE.partial && !STATE.sawInputTranscript) {
          try { console.log("[input transcript]", STATE.partial); } catch {}
          flushPartial();
        }
        // Immediately create a new response to keep streaming
        try {
          dc.send(
            JSON.stringify({
              type: "response.create",
              response: {
                modalities: ["text"],
                instructions:
                  "Transcribe the user's speech verbatim as plain text only. Do not add or change words. No assistant responses; only the exact transcript.",
              },
            }),
          );
        } catch {}
      }
    } catch {}
  });

  try {
    const offer = await pc.createOffer({ offerToReceiveAudio: true, offerToReceiveVideo: false });
    await pc.setLocalDescription(offer);
    await waitForIceGatheringComplete(pc);

    // Direct calls endpoint with ephemeral key (per docs)
    const tokenRes = await fetch("http://localhost:3000/token");
    const token = await tokenRes.json();
    const EPHEMERAL_KEY = token.value;
    const sdpResponse = await fetch(
      "https://api.openai.com/v1/realtime/calls?model=gpt-realtime",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${EPHEMERAL_KEY}`,
          "Content-Type": "application/sdp",
        },
        body: offer.sdp,
      },
    );
    if (!sdpResponse.ok) {
      const errTxt = await sdpResponse.text();
      try {
        fetch("http://localhost:3000/debug/event", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ type: "webrtc.offer_error", status: sdpResponse.status, body: errTxt }),
        });
      } catch {}
      throw new Error(`realtime calls error ${sdpResponse.status}`);
    }
    const sdp = await sdpResponse.text();
    const answer = { type: "answer", sdp };
    await pc.setRemoteDescription(answer);
  } catch (e) {
    console.error("Offscreen webrtc setup error:", e);
  }
}

function stopTranscription() {
  if (!STATE.running) return;
  STATE.running = false;
  try { flushPartial(); } catch {}
  try { if (STATE.dc) STATE.dc.close(); } catch {}
  try { if (STATE.pc) STATE.pc.close(); } catch {}
  try { if (STATE.micStream) STATE.micStream.getTracks().forEach((t) => t.stop()); } catch {}
  STATE.dc = null;
  STATE.pc = null;
  STATE.micStream = null;
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.type === "OFFSCREEN_START") {
    startTranscription();
    sendResponse({ ok: true });
    return true;
  }
  if (msg?.type === "OFFSCREEN_STOP") {
    stopTranscription();
    sendResponse({ ok: true });
    return true;
  }
  if (msg?.type === "OFFSCREEN_PING") {
    sendResponse({ ok: true });
    return true;
  }
});

// Signal readiness to the background script
try { chrome.runtime.sendMessage({ type: "OFFSCREEN_READY" }); } catch {}


