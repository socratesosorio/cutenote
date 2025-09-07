import express from "express";
import fs from "fs";
import { createServer as createViteServer } from "vite";
import "dotenv/config";
import Busboy from "busboy";

const app = express();
const port = process.env.PORT || 3000;
const apiKey = process.env.OPENAI_API_KEY;

// Configure Vite middleware for React client
const vite = await createViteServer({
  server: { middlewareMode: true },
  appType: "custom",
});
app.use(vite.middlewares);

const sessionConfig = JSON.stringify({
  session: {
    type: "realtime",
    model: "gpt-realtime",
    audio: {
      output: { voice: "marin" },
    },
  },
});

// All-in-one SDP request (experimental)
app.post("/session", express.text({ type: "*/*" }), async (req, res) => {
  try {
    const fd = new FormData();
    const sdpIn = typeof req.body === "string" ? req.body : "";
    fd.set("sdp", sdpIn);
    fd.set("session", sessionConfig);

    const r = await fetch("https://api.openai.com/v1/realtime/calls", {
      method: "POST",
      headers: {
        "OpenAI-Beta": "realtime=v1",
        Authorization: `Bearer ${apiKey}`,
      },
      body: fd,
    });

    const text = await r.text();
    if (!r.ok) {
      console.error("/session upstream error", r.status, text);
      return res.status(r.status).send(text);
    }
    // Send back the SDP we received from the OpenAI REST API
    res.type("application/sdp").send(text);
  } catch (e) {
    console.error("/session error", e);
    res.status(500).send("server error");
  }
});

// In-memory transcript and SSE clients
const transcriptSentences = [];
const sseClients = new Set();

// CORS headers for extension calls
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", "*");
  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, Content-Type, Accept, Authorization",
  );
  res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  if (req.method === "OPTIONS") {
    return res.sendStatus(200);
  }
  next();
});

// Lightweight transcription proxy endpoint for Chrome extension
app.post("/transcribe", async (req, res) => {
  try {
    const contentType = String(req.headers["content-type"] || "");
    // Branch: raw audio body
    if (!contentType.includes("multipart/form-data")) {
      const chunks = [];
      req.on("data", (d) => chunks.push(d));
      req.on("end", async () => {
        try {
          const fileBuffer = Buffer.concat(chunks);
          if (!fileBuffer || fileBuffer.length < 8192) {
            return res.json({ text: "" });
          }
          const url = new URL(req.url, `http://${req.headers.host}`);
          const filename = url.searchParams.get("filename") || "audio.webm";
          const mimeType = contentType || "audio/webm";
          const fd = new FormData();
          const file = new File([fileBuffer], filename, { type: mimeType });
          fd.append("file", file);
          fd.append("model", "whisper-1");

          const r = await fetch("https://api.openai.com/v1/audio/transcriptions", {
            method: "POST",
            headers: { Authorization: `Bearer ${apiKey}` },
            body: fd,
          });

          if (!r.ok) {
            const errTxt = await r.text();
            console.error("Transcription error:", r.status, errTxt);
            return res.status(502).json({ error: "Upstream transcription failed", details: errTxt });
          }
          const data = await r.json();
          return res.json({ text: data.text || "" });
        } catch (e) {
          console.error("Transcription proxy error (raw):", e);
          return res.status(500).json({ error: "Transcription proxy error" });
        }
      });
      return;
    }

    // Branch: multipart form-data
    const busboy = Busboy({ headers: req.headers });
    let fileBuffer = Buffer.alloc(0);
    let filename = "audio.webm";
    let mimeType = "audio/webm";

    busboy.on("file", (_name, file, info) => {
      filename = info.filename || filename;
      mimeType = info.mimeType || info.mimetype || mimeType;
      file.on("data", (data) => {
        fileBuffer = Buffer.concat([fileBuffer, data]);
      });
    });

    busboy.on("finish", async () => {
      try {
        if (!fileBuffer || fileBuffer.length < 8192) {
          return res.json({ text: "" });
        }

        const fd = new FormData();
        const file = new File([fileBuffer], filename || "audio.webm", { type: mimeType || "audio/webm" });
        fd.append("file", file);
        fd.append("model", "whisper-1");

        const r = await fetch("https://api.openai.com/v1/audio/transcriptions", {
          method: "POST",
          headers: { Authorization: `Bearer ${apiKey}` },
          body: fd,
        });

        if (!r.ok) {
          const errTxt = await r.text();
          console.error("Transcription error:", r.status, errTxt);
          return res.status(502).json({ error: "Upstream transcription failed", details: errTxt });
        }

        const data = await r.json();
        res.json({ text: data.text || "" });
      } catch (error) {
        console.error("Transcription proxy error:", error);
        res.status(500).json({ error: "Transcription proxy error" });
      }
    });

    req.pipe(busboy);
  } catch (error) {
    console.error("/transcribe setup error:", error);
    res.status(500).json({ error: "Failed to process audio" });
  }
});

// Append transcript sentences (from extension)
app.post("/transcript/append", express.json(), (req, res) => {
  try {
    const { sentence, sentences } = req.body || {};
    const toAdd = [];
    if (typeof sentence === "string" && sentence.trim()) toAdd.push(sentence.trim());
    if (Array.isArray(sentences)) {
      sentences.forEach((s) => {
        if (typeof s === "string" && s.trim()) toAdd.push(s.trim());
      });
    }
    if (toAdd.length === 0) return res.status(400).json({ error: "No sentences" });
    transcriptSentences.push(...toAdd);
    // Broadcast to SSE clients
    const data = JSON.stringify({ type: "append", sentences: toAdd });
    for (const client of sseClients) {
      client.write(`event: transcript\n`);
      client.write(`data: ${data}\n\n`);
    }
    res.json({ ok: true });
  } catch (e) {
    console.error("/transcript/append error:", e);
    res.status(500).json({ error: "append failed" });
  }
});

// Update specific sentence
app.post("/transcript/update", express.json(), (req, res) => {
  try {
    const { index, text } = req.body || {};
    if (typeof index !== "number" || typeof text !== "string") {
      return res.status(400).json({ error: "invalid payload" });
    }
    if (index < 0 || index >= transcriptSentences.length) {
      return res.status(400).json({ error: "index out of range" });
    }
    transcriptSentences[index] = text;
    const data = JSON.stringify({ type: "update", index, text });
    for (const client of sseClients) {
      client.write(`event: transcript\n`);
      client.write(`data: ${data}\n\n`);
    }
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: "update failed" });
  }
});

// Enhance text via Responses API
app.post("/enhance", express.json(), async (req, res) => {
  try {
    const { text } = req.body || {};
    const r = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        input: `Rewrite this line to be clearer and more polished. Keep meaning identical.\n\nLine: ${text}`,
      }),
    });
    const data = await r.json();
    const out = data?.output?.[0]?.content?.[0]?.text || data?.output_text?.[0] || "";
    res.json({ text: out });
  } catch (e) {
    res.status(500).json({ error: "enhance failed" });
  }
});

// Ask GPT about a line
app.post("/ask", express.json(), async (req, res) => {
  try {
    const { text, question } = req.body || {};
    const r = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        input: `You are a helpful assistant. Question about this transcript line.\n\nLine: ${text}\nQuestion: ${question}`,
      }),
    });
    const data = await r.json();
    const out = data?.output?.[0]?.content?.[0]?.text || data?.output_text?.[0] || "";
    res.json({ text: out });
  } catch (e) {
    res.status(500).json({ error: "ask failed" });
  }
});
// Clear transcript
app.post("/transcript/clear", (_req, res) => {
  transcriptSentences.splice(0, transcriptSentences.length);
  const data = JSON.stringify({ type: "clear" });
  for (const client of sseClients) {
    client.write(`event: transcript\n`);
    client.write(`data: ${data}\n\n`);
  }
  res.json({ ok: true });
});

// Export transcript as text
app.get("/transcript/export.txt", (_req, res) => {
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.send(transcriptSentences.join("\n"));
});

// SSE stream for live transcript
app.get("/transcript/stream", (req, res) => {
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
    "Access-Control-Allow-Origin": "*",
  });

  sseClients.add(res);

  // Send initial snapshot
  const initData = JSON.stringify({ type: "snapshot", sentences: transcriptSentences });
  res.write(`event: transcript\n`);
  res.write(`data: ${initData}\n\n`);

  req.on("close", () => {
    try {
      sseClients.delete(res);
      res.end();
    } catch {}
  });
});

// Debug endpoint to log realtime events coming from the extension
// Intentionally no debug logging endpoint to keep terminal clean

// API route for ephemeral token generation
app.get("/token", async (req, res) => {
  try {
    const response = await fetch(
      "https://api.openai.com/v1/realtime/client_secrets",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
          "OpenAI-Beta": "realtime=v1",
        },
        body: sessionConfig,
      },
    );

    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error("Token generation error:", error);
    res.status(500).json({ error: "Failed to generate token" });
  }
});

// Render the React client
app.use("*", async (req, res, next) => {
  const url = req.originalUrl;

  try {
    const template = await vite.transformIndexHtml(
      url,
      fs.readFileSync("./client/index.html", "utf-8"),
    );
    const { render } = await vite.ssrLoadModule("./client/entry-server.jsx");
    const appHtml = await render(url);
    const html = template.replace(`<!--ssr-outlet-->`, appHtml?.html);
    res.status(200).set({ "Content-Type": "text/html" }).end(html);
  } catch (e) {
    vite.ssrFixStacktrace(e);
    next(e);
  }
});

app.listen(port, () => {
  console.log(`Express server running on *:${port}`);
});
