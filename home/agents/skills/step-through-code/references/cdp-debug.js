// CDP interactive debugger controlled via stdin.
// Usage: NODE_PATH=./node_modules node cdp-debug.js <ws-url>
//
// Commands (stdin):
//   bp <url-pattern> <line>   — set breakpoint (0-indexed line)
//   eval <expr>               — evaluate expression in paused frame
//   next                      — step next
//   step                      — step into
//   out                       — step out
//   cont                      — continue
//   list                      — show source around current position
//   quit                      — exit

const WebSocket = require('ws');
const readline = require('readline');

const wsUrl = process.argv[2];
const ws = new WebSocket(wsUrl);
let msgId = 1;
const pending = {};

function send(method, params = {}) {
  return new Promise((resolve) => {
    const id = msgId++;
    pending[id] = resolve;
    ws.send(JSON.stringify({ id, method, params }));
  });
}

let pausedCallFrames = null;

ws.on('message', (raw) => {
  const msg = JSON.parse(raw);
  if (msg.id && pending[msg.id]) {
    pending[msg.id](msg);
    delete pending[msg.id];
  }
  if (msg.method === 'Debugger.paused') {
    pausedCallFrames = msg.params.callFrames;
    const top = pausedCallFrames[0];
    const loc = top.location;
    console.log(`\n⏸  Paused at ${top.url}:${loc.lineNumber + 1}`);
    console.log(`   Function: ${top.functionName || '(anonymous)'}`);
    // show scope variables summary
    console.log('   Ready for commands (eval, next, step, out, cont, list)');
    rl.prompt();
  }
  if (msg.method === 'Debugger.resumed') {
    pausedCallFrames = null;
  }
});

const rl = readline.createInterface({ input: process.stdin, output: process.stdout, prompt: 'cdp> ' });

ws.on('open', async () => {
  await send('Debugger.enable');
  console.log('Connected. Set breakpoints with: bp <url-pattern> <line>');
  rl.prompt();
});

rl.on('line', async (line) => {
  const parts = line.trim().split(/\s+/);
  const cmd = parts[0];

  try {
    switch (cmd) {
      case 'bp': {
        const pattern = parts[1];
        const lineNum = parseInt(parts[2]);
        const res = await send('Debugger.setBreakpointByUrl', {
          urlRegex: pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'),
          lineNumber: lineNum,
          columnNumber: 0,
        });
        if (res.result?.breakpointId) {
          console.log(`✓ Breakpoint: ${res.result.breakpointId}`);
          console.log(`  Locations: ${JSON.stringify(res.result.locations)}`);
        } else {
          console.log(`✗ Failed: ${JSON.stringify(res.error || res)}`);
        }
        break;
      }
      case 'eval': {
        if (!pausedCallFrames) { console.log('Not paused'); break; }
        const expr = parts.slice(1).join(' ');
        const res = await send('Debugger.evaluateOnCallFrame', {
          callFrameId: pausedCallFrames[0].callFrameId,
          expression: expr,
          returnByValue: true,
        });
        if (res.result?.result) {
          const r = res.result.result;
          console.log(r.value !== undefined ? r.value : `[${r.type}] ${r.description || ''}`);
        } else {
          console.log(JSON.stringify(res));
        }
        break;
      }
      case 'next': await send('Debugger.stepOver'); break;
      case 'step': await send('Debugger.stepInto'); break;
      case 'out':  await send('Debugger.stepOut');  break;
      case 'cont': await send('Debugger.resume');   break;
      case 'list': {
        if (!pausedCallFrames) { console.log('Not paused'); break; }
        const top = pausedCallFrames[0];
        const res = await send('Debugger.getScriptSource', { scriptId: top.location.scriptId });
        if (res.result?.scriptSource) {
          const lines = res.result.scriptSource.split('\n');
          const cur = top.location.lineNumber;
          const start = Math.max(0, cur - 3);
          const end = Math.min(lines.length, cur + 4);
          for (let i = start; i < end; i++) {
            const marker = i === cur ? '>' : ' ';
            console.log(`${marker}${(i + 1).toString().padStart(4)} ${lines[i]}`);
          }
        }
        break;
      }
      case 'quit': ws.close(); process.exit(0);
      default: console.log('Unknown command. Try: bp, eval, next, step, out, cont, list, quit');
    }
  } catch (e) {
    console.log(`Error: ${e.message}`);
  }
  rl.prompt();
});
