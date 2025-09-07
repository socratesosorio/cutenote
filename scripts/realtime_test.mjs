import 'dotenv/config';
import wrtc from 'wrtc';

async function waitForIceGatheringComplete(pc) {
  if (pc.iceGatheringState === 'complete') return;
  await new Promise((resolve) => {
    function check() {
      if (pc.iceGatheringState === 'complete') {
        pc.removeEventListener('icegatheringstatechange', check);
        resolve();
      }
    }
    pc.addEventListener('icegatheringstatechange', check);
  });
}

async function main() {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    console.error('OPENAI_API_KEY is not set. Add it to .env');
    process.exit(1);
  }

  const pc = new wrtc.RTCPeerConnection();

  const dc = pc.createDataChannel('oai-events');
  dc.onopen = () => {
    console.log('[dc] open');
    const sessionUpdate = {
      type: 'session.update',
      session: {
        type: 'realtime',
        instructions: 'You are a minimal test agent. Respond succinctly.'
      }
    };
    dc.send(JSON.stringify(sessionUpdate));

    const msg = {
      type: 'conversation.item.create',
      item: {
        type: 'message',
        role: 'user',
        content: [
          { type: 'input_text', text: 'Say exactly: Realtime test connection is working.' }
        ]
      }
    };
    dc.send(JSON.stringify(msg));
    dc.send(JSON.stringify({ type: 'response.create' }));
  };

  let transcript = '';
  dc.onmessage = (e) => {
    try {
      const evt = JSON.parse(e.data);
      if (evt.type === 'response.output_text.delta' && typeof evt.text === 'string') {
        transcript += evt.text;
        process.stdout.write(evt.text);
      } else if (evt.type === 'response.done') {
        console.log('\n[dc] response.done');
        // Close after first response
        try { dc.close(); } catch {}
        try { pc.close(); } catch {}
        process.exit(0);
      }
    } catch (err) {
      // ignore non-JSON messages
    }
  };

  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  await waitForIceGatheringComplete(pc);

  const sdp = pc.localDescription.sdp;
  const r = await fetch('https://api.openai.com/v1/realtime/calls?model=gpt-realtime', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'OpenAI-Beta': 'realtime=v1',
      'Content-Type': 'application/sdp'
    },
    body: sdp
  });

  if (!r.ok) {
    console.error('[http] failed', r.status, await r.text());
    process.exit(1);
  }

  const answer = await r.text();
  await pc.setRemoteDescription({ type: 'answer', sdp: answer });
  console.log('[http] connected');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});


