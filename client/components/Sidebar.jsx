import { useEffect, useRef, useState } from "react";

function Instructions() {
  return (
    <div className="text-sm text-gray-700 leading-6 space-y-3">
      <p><b>Start/Stop</b>: Click the extension and press Start. A pulsing mic shows it’s recording.</p>
      <p><b>Side panel</b>: Draggable and resizable. Text is selectable and updates in real time.</p>
      <p><b>Edit</b>: Double‑click any line to edit and save.</p>
      <p><b>Enhance</b>: Hover a line → Enhance to get a cleaner rewrite. Accept/Reject the suggestion beneath it.</p>
      <p><b>Ask GPT</b>: Hover a line → Ask GPT. The chatbot opens with the question prefilled.</p>
      <p><b>Export</b>: Use Download .txt or Export to Google Docs in the console footer.</p>
    </div>
  );
}

function Chatbot({ prefill }) {
  const [input, setInput] = useState(prefill || "");
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => { if (prefill) setInput(prefill); }, [prefill]);

  async function send() {
    const text = input.trim();
    if (!text) return;
    setMessages((m) => [...m, { role: "user", text }]);
    setInput("");
    setLoading(true);
    try {
      const r = await fetch("/ask", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ text: "(context from transcript)", question: text }) });
      const data = await r.json();
      setMessages((m) => [...m, { role: "assistant", text: data?.text || "" }]);
    } finally { setLoading(false); }
  }

  return (
    <div className="flex flex-col h-full gap-3">
      <div className="flex-1 overflow-auto space-y-2">
        {messages.map((m, i) => (
          <div key={i} className={m.role === "user" ? "text-gray-900" : "text-gray-700"}>
            {m.role === "user" ? "You: " : "GPT: "}{m.text}
          </div>
        ))}
        {loading && <div className="text-gray-500 text-sm">Thinking…</div>}
      </div>
      <div className="flex gap-2 mb-12">
        <input className="flex-1 border border-gray-300 rounded px-2 py-1" value={input} onChange={(e) => setInput(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') send(); }} placeholder="Ask a question…" />
        <button className="bg-blue-600 text-white rounded px-3" onClick={send}>Send</button>
      </div>
    </div>
  );
}

export default function Sidebar() {
  const [width, setWidth] = useState(380);
  const [collapsed, setCollapsed] = useState(false);
  const [tab, setTab] = useState("instructions");
  const [prefill, setPrefill] = useState("");
  const dragRef = useRef(null);
  const startX = useRef(0);
  const startW = useRef(0);

  useEffect(() => {
    function openChat(e) {
      const { question } = e.detail || {};
      setTab("chat");
      setPrefill(question || "");
      setCollapsed(false);
    }
    window.addEventListener("sidebar:openChat", openChat);
    return () => window.removeEventListener("sidebar:openChat", openChat);
  }, []);

  function onMouseDown(e) {
    startX.current = e.clientX;
    startW.current = width;
    function move(ev) { setWidth(Math.min(800, Math.max(280, startW.current - (ev.clientX - startX.current)))); }
    function up() { window.removeEventListener("mousemove", move); window.removeEventListener("mouseup", up); }
    window.addEventListener("mousemove", move);
    window.addEventListener("mouseup", up);
  }

  return (
    <aside className="absolute top-0 bottom-0 right-0 flex" style={{ width: collapsed ? 36 : width }}>
      <div className="flex-1 h-full p-4 overflow-hidden border-l border-gray-200 bg-white">
        <div className="flex items-center justify-between mb-3">
          <div className="flex gap-2 text-sm">
            <button className={tab === "instructions" ? "text-blue-600" : "text-gray-600"} onClick={() => setTab("instructions")}>Instructions</button>
            <button className={tab === "chat" ? "text-blue-600" : "text-gray-600"} onClick={() => setTab("chat")}>Chatbot</button>
          </div>
          <button className="text-gray-500" onClick={() => setCollapsed(!collapsed)}>{collapsed ? ">" : "×"}</button>
        </div>
        {tab === "instructions" ? <Instructions /> : <Chatbot prefill={prefill} />}
      </div>
      <div ref={dragRef} className="w-2 cursor-col-resize bg-transparent" onMouseDown={onMouseDown} />
    </aside>
  );
}


