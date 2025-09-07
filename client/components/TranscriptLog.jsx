import { useEffect, useRef, useState } from "react";

export default function TranscriptLog() {
  const [sentences, setSentences] = useState([]);
  const esRef = useRef(null);
  const [hoverIdx, setHoverIdx] = useState(-1);
  const [editingIdx, setEditingIdx] = useState(-1);
  const [draft, setDraft] = useState("");
  const [suggestions, setSuggestions] = useState({});

  useEffect(() => {
    const es = new EventSource("/transcript/stream");
    esRef.current = es;
    es.addEventListener("transcript", (e) => {
      try {
        const msg = JSON.parse(e.data || "{}");
        if (msg.type === "snapshot" && Array.isArray(msg.sentences)) {
          setSentences(msg.sentences);
        } else if (msg.type === "append" && Array.isArray(msg.sentences)) {
          setSentences((prev) => [...prev, ...msg.sentences]);
        } else if (msg.type === "update" && typeof msg.index === "number") {
          setSentences((prev) => prev.map((s, i) => (i === msg.index ? msg.text : s)));
        } else if (msg.type === "clear") {
          setSentences([]);
        }
      } catch {}
    });
    return () => {
      try { es.close(); } catch {}
    };
  }, []);

  async function enhance(idx) {
    try {
      const res = await fetch("/enhance", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ text: sentences[idx] }) });
      const data = await res.json();
      if (data?.text) setSuggestions((m) => ({ ...m, [idx]: data.text }));
    } catch {}
  }

  async function askGpt(idx) {
    const question = `Question about this line: ${sentences[idx]}`;
    window.dispatchEvent(new CustomEvent("sidebar:openChat", { detail: { question } }));
  }

  async function update(idx, text) {
    try {
      await fetch("/transcript/update", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ index: idx, text }) });
      setSuggestions((m) => { const n = { ...m }; delete n[idx]; return n; });
    } catch {}
  }

  return (
    <div className="flex flex-col gap-2 overflow-x-auto">
      {sentences.length === 0 ? (
        <div className="text-gray-500">Awaiting transcript...</div>
      ) : (
        sentences.map((s, i) => (
          <div
            key={i}
            className="group text-sm text-gray-800 select-text flex items-start justify-between gap-2 px-2 py-1 rounded hover:bg-gray-50"
            onMouseEnter={() => setHoverIdx(i)}
            onMouseLeave={() => setHoverIdx(-1)}
          >
            {editingIdx === i ? (
              <input
                className="flex-1 border border-gray-300 rounded px-2 py-1"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onBlur={() => { setEditingIdx(-1); update(i, draft); }}
                onKeyDown={(e) => { if (e.key === 'Enter') { setEditingIdx(-1); update(i, draft); } }}
                autoFocus
              />
            ) : (
              <span onDoubleClick={() => { setEditingIdx(i); setDraft(s); }}>{s}</span>
            )}
            <div className="opacity-0 group-hover:opacity-100 transition-opacity flex gap-2">
              <button className="text-blue-600 text-xs" onClick={() => enhance(i)}>Enhance</button>
              <button className="text-purple-600 text-xs" onClick={() => askGpt(i)}>Ask GPT</button>
              <button className="text-gray-500 text-xs" onClick={() => { setEditingIdx(i); setDraft(s); }}>Edit</button>
            </div>
            {suggestions[i] && (
              <div className="pl-3 mt-1 text-sm text-gray-600 border-l-2 border-blue-200">
                <div className="mb-1">{suggestions[i]}</div>
                <div className="flex gap-2">
                  <button className="text-blue-600 text-xs" onClick={() => update(i, suggestions[i])}>Accept</button>
                  <button className="text-red-500 text-xs" onClick={() => setSuggestions((m) => { const n = { ...m }; delete n[i]; return n; })}>Reject</button>
                </div>
              </div>
            )}
          </div>
        ))
      )}
    </div>
  );
}


