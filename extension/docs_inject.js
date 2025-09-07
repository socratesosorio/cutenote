// Receives transcript text and inserts into the active Google Doc without user paste
function findEditorWindow(win) {
  try {
    // Google Docs keeps an input iframe for text events
    for (const frame of win.document.querySelectorAll('iframe')) {
      const id = frame.id || '';
      if (id.includes('docs-texteventtarget')) {
        return frame.contentWindow;
      }
    }
    // Fallback: search recursively
    for (const frame of win.frames) {
      const found = findEditorWindow(frame);
      if (found) return found;
    }
  } catch {}
  return null;
}

function insertTextAtCursor(text) {
  const targetWin = findEditorWindow(window) || window;
  try {
    targetWin.focus();
  } catch {}
  try {
    targetWin.document.execCommand('insertText', false, text);
    return true;
  } catch (e) {
    try {
      const sel = targetWin.getSelection();
      if (!sel || !sel.rangeCount) return false;
      sel.deleteFromDocument();
      sel.getRangeAt(0).insertNode(targetWin.document.createTextNode(text));
      sel.collapseToEnd();
      return true;
    } catch {}
  }
  return false;
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === 'DOCS_POPULATE' && typeof message.text === 'string') {
    let ok = insertTextAtCursor(message.text);
    if (!ok) {
      // Retry shortly; docs may still be initializing
      setTimeout(() => insertTextAtCursor(message.text), 800);
      setTimeout(() => insertTextAtCursor(message.text), 1600);
    }
    sendResponse?.({ ok });
    return true;
  }
});


