import puppeteer from 'puppeteer';

async function main() {
  const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox'] });
  const page = await browser.newPage();

  page.on('console', (msg) => {
    const text = msg.text();
    console.log('[browser]', text);
  });

  await page.goto('http://localhost:3000');

  await page.evaluate(async () => {
    function log(...args) { console.log(...args); }
    const tokenRes = await fetch('/token');
    const tokenData = await tokenRes.json();
    const EPHEMERAL_KEY = tokenData.value;
    if (!EPHEMERAL_KEY) { throw new Error('No ephemeral token'); }

    const pc = new RTCPeerConnection();
    // Add a synthetic audio track so the offer has an audio m-line
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const osc = ctx.createOscillator();
    const dest = ctx.createMediaStreamDestination();
    osc.connect(dest);
    osc.start();
    const ms = dest.stream;
    const [track] = ms.getAudioTracks();
    if (track) pc.addTrack(track, ms);
    const dc = pc.createDataChannel('oai-events');
    dc.addEventListener('open', () => {
      log('dc open');
      const sessionUpdate = {
        type: 'session.update',
        session: { type: 'realtime', instructions: 'You are a test agent. Reply succinctly.' },
      };
      dc.send(JSON.stringify(sessionUpdate));
      dc.send(JSON.stringify({
        type: 'conversation.item.create',
        item: { type: 'message', role: 'user', content: [{ type: 'input_text', text: 'Say: Realtime works.' }] }
      }));
      dc.send(JSON.stringify({ type: 'response.create' }));
    });
    dc.addEventListener('message', (e) => {
      try {
        const evt = JSON.parse(e.data);
        if (evt.type === 'response.output_text.delta' && typeof evt.text === 'string') {
          log('delta', evt.text);
        } else if (evt.type === 'response.done') {
          log('done');
        }
      } catch {}
    });

    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    const r = await fetch('https://api.openai.com/v1/realtime/calls?model=gpt-realtime', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${EPHEMERAL_KEY}`,
        'Content-Type': 'application/sdp',
        'OpenAI-Beta': 'realtime=v1'
      },
      body: offer.sdp,
    });
    if (!r.ok) {
      const err = await r.text();
      console.log('calls 400/500:', err);
      throw new Error('calls failed');
    }
    const sdp = await r.text();
    await pc.setRemoteDescription({ type: 'answer', sdp });
  });

  // Keep process alive for 10s to collect deltas
  await new Promise((r) => setTimeout(r, 10000));
  await browser.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});


