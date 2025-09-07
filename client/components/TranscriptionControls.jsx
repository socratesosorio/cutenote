export default function TranscriptionControls() {
  function setScale(delta) {
    try {
      const cur = Number(localStorage.getItem("consoleFontScale") || "1");
      const next = Math.min(1.6, Math.max(0.8, cur + delta));
      localStorage.setItem("consoleFontScale", String(next));
      document.documentElement.style.fontSize = `${next * 16}px`;
    } catch {}
  }

  // Initialize scale
  try {
    const cur = Number(localStorage.getItem("consoleFontScale") || "1");
    document.documentElement.style.fontSize = `${cur * 16}px`;
  } catch {}

  return (
    <div className="flex items-center justify-between gap-4 w-full h-full">
      <div className="text-sm text-gray-600">Live Transcription</div>
      <div className="flex items-center gap-3">
        <button
          className="bg-gray-100 text-gray-900 border border-gray-300 rounded-full px-3 py-2 hover:bg-gray-200"
          onClick={() => setScale(-0.05)}
        >
          A-
        </button>
        <button
          className="bg-gray-100 text-gray-900 border border-gray-300 rounded-full px-3 py-2 hover:bg-gray-200"
          onClick={() => setScale(0.05)}
        >
          A+
        </button>
        <a
          href="/transcript/export.txt"
          className="bg-gray-900 text-white rounded-full px-4 py-2 hover:opacity-90"
          download
        >
          Download .txt
        </a>
        <button
          className="bg-gray-100 text-gray-900 border border-gray-300 rounded-full px-4 py-2 hover:bg-gray-200"
          onClick={async () => {
            await fetch("/transcript/clear", { method: "POST" });
          }}
        >
          Clear
        </button>
        <button
          className="bg-blue-600 text-white rounded-full px-4 py-2 hover:bg-blue-700"
          onClick={async () => {
            const res = await fetch("/transcript/export.txt");
            const text = await res.text();
            await navigator.clipboard.writeText(text);
            window.open("https://docs.new", "_blank");
          }}
        >
          Export to Google Docs
        </button>
      </div>
    </div>
  );
}


