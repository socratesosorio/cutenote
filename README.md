# cutenote realtime version<3

Real‑time voice‑to‑text for the browser using OpenAI Realtime (WebRTC) + a Chrome extension + a sleek React console.

## Quick Start (TL;DR)

```bash
# 1) Install
npm install

# 2) Configure env
echo "OPENAI_API_KEY=sk-your-key" > .env

# 3) Run server
npm run dev   # http://localhost:3000

# 4) Load the extension
# Chrome → chrome://extensions → Developer mode → Load unpacked → select extension/

# 5) Start from the popup
# Click Start (allow mic). Transcript appears in the mini panel and console.
```

Granola Realtime gives you:
- A Chrome extension that captures the microphone and streams audio to OpenAI over WebRTC
- A resilient Realtime client that extracts transcripts even when input‑transcript events aren’t enabled
- A React console with a live, editable transcript, “Enhance”/“Ask GPT” helpers, zoom controls, and one‑click export
- A draggable, resizable mini panel that appears on any page (and on Chrome’s New Tab) with quick copy/zoom

Docs referenced:
- Realtime guide: https://platform.openai.com/docs/guides/realtime
- Realtime WebRTC: https://platform.openai.com/docs/guides/realtime-webrtc

---

## 1) Quick Start

1. Install
```bash
npm install
```

2. Environment
Create `.env` with:
```
OPENAI_API_KEY=sk-your-key
PORT=3000
```

3. Run the server
```bash
npm run dev
```
Open http://localhost:3000

4. Load the Chrome extension
- Go to `chrome://extensions`, enable Developer mode
- Load unpacked → select `extension/`

5. Start transcribing
- Click the extension → Start (allow mic)
- Transcript streams into the mini panel and the console

---

## 2) Architecture

- `server.js` (Express)
  - Issues ephemeral tokens: `GET /token` → `POST /v1/realtime/client_secrets`
  - Holds transcript and broadcasts over SSE: `GET /transcript/stream`
  - Transcript ops: `POST /transcript/append|update|clear` and `GET /transcript/export.txt`
  - Helpers: `POST /enhance` and `POST /ask` via OpenAI Responses API
- `extension/` (Chrome MV3)
  - `offscreen.js`: WebRTC session, mic capture, spacing normalization
  - `background.js`: lifecycle, fan‑out to tabs, Google Docs export
  - `content.js|css`: draggable mini panel; zoom; quick copy per row
  - `docs_inject.js`: inserts transcript into Google Docs without paste
- `client/` (React + Vite)
  - `TranscriptLog.jsx`: live SSE transcript, edit/save, enhance, ask GPT
  - `TranscriptionControls.jsx`: Download / Clear / Docs export / Zoom A‑/A+
  - `Sidebar.jsx`: draggable/resizable sidebar with Instructions and Chatbot

---

## 3) Using the App

### Extension (Start/Stop)
1) Click the extension icon → Start (allow microphone)
2) A pulsing mic shows it’s recording; click Stop to end
3) Text appears in the mini panel and in the console

### Mini Panel
- Drag by header; resize from corner; A‑ / A+ zoom in header
- Hover a line → Copy appears; click to copy
- Size/position/zoom persist; shows on Chrome’s New Tab page too

### React Console
- Live transcript list; hover a line to reveal:
  - Copy: copy that line
  - Edit: double‑click → edit → blur/Enter saves
  - Enhance: `/enhance` suggests a rewrite; appears in gray under the line with Accept/Reject
  - Ask GPT: opens the right sidebar Chatbot, prefilled with your question
- Footer: Download .txt, Clear transcript, Export to Google Docs, A‑ / A+ zoom
- Right Sidebar (Instructions / Chatbot)
  - Drag handle to resize; collapse/expand with the × toggle
  - Input stays visible; no awkward scrolling

### Export to Google Docs (no paste)
- Click “Export to Google Docs” (console or popup)
- We open `docs.new` and auto‑insert the transcript
- If Docs is slow to initialize, we retry; on rare networks, paste manually

---

## 4) Realtime Flow (WebRTC)

1) Offscreen captures mic with `getUserMedia` and creates `RTCPeerConnection`
2) Requests an ephemeral key from the server (`GET /token`)
3) Posts the SDP offer to `POST /v1/realtime/calls?model=gpt-realtime`
4) Receives SDP answer → sets remote description → data channel opens
5) Sends minimal `session.update` (text‑only steering) and loops `response.create`
6) Extracts transcript via dual‑path:
   - Preferred: `input_audio_transcript.delta/done` (if available)
   - Fallback: `response.output_text.delta` and `response.output_audio_transcript.*`
7) Normalizes spacing and sends sentences to the server and panel

Why dual‑path?
- Some accounts don’t emit input‑transcript events in realtime; we transparently fall back to output deltas so the UX always works

---

## 5) Server API (Summary)

Token
- `GET /token` → `{ value: "ek_..." }` (use as `Authorization: Bearer` for Realtime `calls`)

Transcript
- `GET /transcript/stream` (SSE): emits `snapshot | append | update | clear`
- `POST /transcript/append` `{ sentence?, sentences? }`
- `POST /transcript/update` `{ index, text }`
- `POST /transcript/clear`
- `GET /transcript/export.txt`

Helpers
- `POST /enhance` `{ text }` → `{ text }` (rewrite/clarify with Responses API)
- `POST /ask` `{ text, question }` → `{ text }` (Q&A about the line)

---

## 6) Configuration

`.env`
```
OPENAI_API_KEY=sk-...
PORT=3000
```

Extension permissions
- Microphone, Storage, Downloads, Tabs, Offscreen
- Hosts: `http://localhost:3000/*`, `https://docs.google.com/*`

---

## 7) Troubleshooting

401 on `realtime/calls`
- Use the ephemeral key from `/token` as `Authorization: Bearer ek_...`

Invalid SDP / “Expect line: v=”
- The upstream response wasn’t SDP. Check server logs for the error text

No transcript appears
- Your account might not emit input transcripts; fallback to output deltas is automatic. Ensure at least one path is producing text

Mic/offscreen issues
- Reload the extension; click Start; allow the microphone when prompted

Docs export blank
- We retry injection; if it still doesn’t appear, paste manually (rare timing edge)

---

## 8) Development Notes

- UI only changes live in `client/components/*` and `extension/content.*`
- Realtime tuning: steer with `session.update` and `response.create`
- Spacing normalization is in `extension/offscreen.js` and `extension/content.js`

---

## License

MIT
