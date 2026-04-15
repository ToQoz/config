/**
 * Slack message operations.
 *
 * Subcommands:
 *   get    <url|channel --ts ts>        Fetch a single message
 *   list   <url>                        Fetch full thread replies
 *   list   <channel> [--limit N]        Fetch channel history
 *   draft  <channel|url> [initial-text] Open browser rich-text editor
 *   send   <channel|url> <text>         Post a message
 *   edit   <url|channel --ts ts> <text> Edit a message
 *   delete <url|channel --ts ts>        Delete a message
 *   react  add|remove <url> <emoji>     Add/remove reaction
 *
 * Common options: --workspace <url-or-substring>
 */

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { spawn } from "node:child_process";
import {
  loadAuth,
  getWorkspaceAuth,
  slackGet,
  slackPost,
  parseSlackUrl,
  resolveChannel,
  parseArgs,
  output,
  fatal,
  usage,
  type WorkspaceAuth,
} from "./helpers/index.ts";

export async function main(args: string[]) {
  const { flags, positional } = parseArgs(args);
  const workspace = flags["workspace"] as string | undefined;
  const config = await loadAuth();
  const auth = getWorkspaceAuth(config, workspace);
  const cmd = positional[0];

  switch (cmd) {
    case "get":    await cmdGet(positional, flags, auth);    break;
    case "list":   await cmdList(positional, flags, auth);   break;
    case "draft":  await cmdDraft(positional, flags, auth);  break;
    case "send":   await cmdSend(positional, flags, auth);   break;
    case "edit":   await cmdEdit(positional, flags, auth);   break;
    case "delete": await cmdDelete(positional, flags, auth); break;
    case "react":  await cmdReact(positional, flags, auth);  break;
    default: usage(
      "Usage: slack-cli message <get|list|draft|send|edit|delete|react> [args]\n" +
      "       slack-cli message get <url|channel --ts ts>\n" +
      "       slack-cli message list <url|channel> [--limit N] [--thread-ts ts]\n" +
      "       slack-cli message draft <channel|url> [text]\n" +
      "       slack-cli message send <channel|url> <text>\n" +
      "       slack-cli message edit <url> <text>\n" +
      "       slack-cli message delete <url>\n" +
      "       slack-cli message react add|remove <url> <emoji>",
    );
  }
}

type Flags = Record<string, string | boolean>;

// ── get ───────────────────────────────────────────────────────────

async function cmdGet(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  if (!target) usage("Usage: slack-cli message get <url|channel --ts ts>");

  const { channel, ts } = await resolveMessageTarget(
    target, flags["ts"] as string | undefined, auth,
  );

  const data = await slackGet<{ messages: unknown[] }>(
    "conversations.history",
    { channel, latest: ts, oldest: ts, inclusive: true, limit: 1 },
    auth,
  );

  const msg = data.messages[0];
  if (!msg) fatal(`Message not found: channel=${channel} ts=${ts}`);
  output({ message: msg });
}

// ── list ──────────────────────────────────────────────────────────

async function cmdList(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  if (!target) usage("Usage: slack-cli message list <url|channel> [--limit N] [--thread-ts ts]");

  const limit = Number(flags["limit"] ?? 25);
  const threadTsFlag = flags["thread-ts"] as string | undefined;
  const parsed = parseSlackUrl(target);

  if (parsed) {
    const threadTs = threadTsFlag ?? parsed.threadTs ?? parsed.ts;
    const data = await slackGet<{ messages: unknown[]; has_more: boolean }>(
      "conversations.replies",
      { channel: parsed.channel, ts: threadTs, limit },
      auth,
    );
    output({ messages: data.messages, has_more: data.has_more });
  } else {
    const channel = await resolveChannel(target, auth);
    if (threadTsFlag) {
      const data = await slackGet<{ messages: unknown[]; has_more: boolean }>(
        "conversations.replies",
        { channel, ts: threadTsFlag, limit },
        auth,
      );
      output({ messages: data.messages, has_more: data.has_more });
    } else {
      const oldest = flags["oldest"] as string | undefined;
      const latest = flags["latest"] as string | undefined;
      const data = await slackGet<{ messages: unknown[]; has_more: boolean }>(
        "conversations.history",
        { channel, limit, oldest, latest },
        auth,
      );
      output({ messages: data.messages, has_more: data.has_more });
    }
  }
}

// ── draft ─────────────────────────────────────────────────────────

async function cmdDraft(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  if (!target) usage("Usage: slack-cli message draft <channel|url> [initial-text]");

  const initialText = positional.slice(2).join(" ");
  const parsed = parseSlackUrl(target);

  let channel: string;
  let threadTs: string | undefined;
  let displayTarget: string;
  let parentMessage: string | undefined;
  let teamId: string | undefined;

  if (parsed) {
    channel = parsed.channel;
    threadTs = parsed.threadTs ?? parsed.ts;
    const [chanInfo, parentMsg] = await Promise.all([
      slackGet<{ channel?: { name?: string; is_im?: boolean; user?: string; context_team_id?: string } }>(
        "conversations.info", { channel }, auth,
      ).catch(() => null),
      slackGet<{ messages?: Array<{ text?: string }> }>(
        "conversations.history",
        { channel, latest: threadTs, oldest: threadTs, inclusive: true, limit: 1 },
        auth,
      ).catch(() => null),
    ]);
    displayTarget = await resolveChannelDisplayName(chanInfo?.channel, auth);
    parentMessage = parentMsg?.messages?.[0]?.text;
    teamId = chanInfo?.channel?.context_team_id;
  } else {
    channel = await resolveChannel(target, auth);
    displayTarget = target.startsWith("#") ? target : `#${target}`;
    threadTs = flags["thread-ts"] as string | undefined;
    if (threadTs) {
      const parentMsg = await slackGet<{ messages?: Array<{ text?: string }> }>(
        "conversations.history",
        { channel, latest: threadTs, oldest: threadTs, inclusive: true, limit: 1 },
        auth,
      ).catch(() => null);
      parentMessage = parentMsg?.messages?.[0]?.text;
    }
  }

  let resolveReady: () => void;
  const done = new Promise<void>((r) => { resolveReady = r; });

  function readBody(req: IncomingMessage): Promise<string> {
    return new Promise((resolve) => {
      const chunks: Buffer[] = [];
      req.on("data", (c: Buffer) => chunks.push(c));
      req.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    });
  }

  const server = createServer(async (req: IncomingMessage, res: ServerResponse) => {
    const url = new URL(req.url ?? "/", `http://${req.headers.host}`);

    if (req.method === "GET" && url.pathname === "/") {
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      res.end(buildEditorHtml(displayTarget, auth.teamName ?? auth.workspaceUrl, initialText, threadTs, parentMessage));
      return;
    }

    if (req.method === "POST" && url.pathname === "/send") {
      const raw = await readBody(req);
      const { text, thread_ts } = JSON.parse(raw) as {
        text: string;
        thread_ts?: string | null;
      };
      try {
        const body: Record<string, unknown> = { channel, text };
        if (thread_ts) body.thread_ts = thread_ts;
        const result = await slackPost<{ channel: string; ts: string }>(
          "chat.postMessage",
          body,
          auth,
        );
        const msgUrl =
          `${auth.workspaceUrl}/archives/${result.channel}/p${result.ts.replace(".", "")}`;
        // slack:// URL scheme to open the message in Slack Desktop
        const slackUrl = teamId
          ? `slack://channel?team=${teamId}&id=${result.channel}&message=${result.ts}`
          : null;
        setTimeout(() => resolveReady(), 1500);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true, message_url: msgUrl, slack_url: slackUrl }));
      } catch (e) {
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: false, error: (e as Error).message }));
      }
      return;
    }

    if (url.pathname === "/close") {
      setTimeout(() => resolveReady(), 100);
      res.end("ok");
      return;
    }

    res.writeHead(404);
    res.end("Not Found");
  });

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const addr = server.address() as { port: number };
  const editorUrl = `http://127.0.0.1:${addr.port}`;

  console.error(`Draft editor: ${editorUrl}`);
  spawn("open", [editorUrl], { detached: true, stdio: "ignore" }).unref();

  process.on("SIGINT", () => resolveReady());
  await done;
  server.close();
}

function buildEditorHtml(
  target: string,
  workspace: string,
  initialText: string,
  threadTs?: string,
  parentMessage?: string,
): string {
  const safe = (s: string) => s.replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  const parentHtml = parentMessage
    ? `<div class="parent"><div class="parent-label">Replying to:</div><div class="parent-text">${safe(parentMessage)}</div></div>`
    : "";
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Draft — ${safe(target)}</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,system-ui,"Segoe UI",Helvetica,Arial,sans-serif;font-size:15px;background:#fff;color:#1d1c1d}
.app{max-width:720px;margin:48px auto;padding:0 24px}
h1{font-size:18px;font-weight:700;margin-bottom:4px}
.to{color:#616061;font-size:14px;margin-bottom:8px}
.parent{background:#f8f8f8;border-left:4px solid #e8912d;border-radius:4px;padding:8px 12px;margin-bottom:16px;font-size:14px}
.parent-label{color:#616061;font-size:12px;font-weight:600;margin-bottom:4px}
.parent-text{color:#1d1c1d;white-space:pre-wrap;word-break:break-word;max-height:120px;overflow-y:auto}
.box{border:1px solid #d6d0ce;border-radius:8px;overflow:hidden}
.tb{display:flex;gap:2px;padding:6px 8px;border-bottom:1px solid #d6d0ce;background:#f8f8f8}
.tb button{background:none;border:none;cursor:pointer;padding:3px 8px;border-radius:4px;font-size:13px;color:#1d1c1d}
.tb button:hover{background:#e8e8e8}
.sep{width:1px;background:#d6d0ce;margin:2px 4px;align-self:stretch}
.ed{padding:12px;min-height:160px;outline:none;line-height:1.5;white-space:pre-wrap;word-break:break-word}
.ed:empty::before{content:attr(data-ph);color:#a8a8a8;pointer-events:none}
.act{display:flex;align-items:center;justify-content:flex-end;padding:8px 12px;border-top:1px solid #d6d0ce;background:#f8f8f8;gap:8px}
.st{font-size:13px;color:#616061}
.btn{background:#4A154B;color:#fff;border:none;border-radius:4px;padding:7px 16px;font-size:15px;font-weight:700;cursor:pointer}
.btn:hover{background:#611f64}.btn:disabled{background:#d6d0ce;cursor:not-allowed}
.ok{background:#f0f9f0;border:1px solid #aee6a9;border-radius:8px;padding:20px;text-align:center;margin-top:16px;display:none}
.ok a{color:#4A154B;font-weight:700}
</style>
</head>
<body>
<div class="app">
<h1>New Message</h1>
<p class="to">Workspace: <strong>${safe(workspace)}</strong> / Channel: <strong>${safe(target)}</strong>${threadTs ? " (thread reply)" : ""}</p>
${parentHtml}
<div class="box">
  <div class="tb">
    <button title="Bold" onclick="fmt('bold')"><b>B</b></button>
    <button title="Italic" onclick="fmt('italic')"><em>I</em></button>
    <button title="Strikethrough" onclick="fmt('strikeThrough')"><s>S</s></button>
    <div class="sep"></div>
    <button title="Inline code" onclick="wrap('\`','\`')"><code>code</code></button>
    <button title="Code block" onclick="wrap('\`\`\`\\n','\\n\`\`\`')">{ }</button>
  </div>
  <div id="ed" class="ed" contenteditable="true" data-ph="Message ${safe(target)}" spellcheck="true"></div>
  <div class="act">
    <span class="st" id="st"></span>
    <button class="btn" id="btn" onclick="send()">Send</button>
  </div>
</div>
<div class="ok" id="ok">Message sent!<p style="margin-top:8px;font-size:13px;color:#616061">You can close this tab.</p></div>
</div>
<script>
const INIT=${JSON.stringify(initialText)};
const THREAD_TS=${JSON.stringify(threadTs ?? null)};
const ed=document.getElementById('ed'),st=document.getElementById('st'),btn=document.getElementById('btn');
if(INIT)ed.innerText=INIT;
ed.focus();
const r=document.createRange();r.selectNodeContents(ed);r.collapse(false);
const sel=window.getSelection();sel.removeAllRanges();sel.addRange(r);
ed.addEventListener('keydown',e=>{
  if((e.metaKey||e.ctrlKey)&&e.key==='b'){e.preventDefault();fmt('bold')}
  if((e.metaKey||e.ctrlKey)&&e.key==='i'){e.preventDefault();fmt('italic')}
  if((e.metaKey||e.ctrlKey)&&e.key==='Enter'){e.preventDefault();send()}
});
function fmt(cmd){document.execCommand(cmd,false,null);ed.focus()}
function wrap(open,close){
  const t=window.getSelection().toString();
  document.execCommand('insertText',false,t?open+t+close:open+close);ed.focus();
}
function toMrkdwn(el){
  let s='';
  for(const n of el.childNodes){
    if(n.nodeType===3)s+=n.textContent;
    else if(n.nodeName==='BR')s+='\\n';
    else if(n.nodeName==='B'||n.nodeName==='STRONG')s+='*'+toMrkdwn(n)+'*';
    else if(n.nodeName==='I'||n.nodeName==='EM')s+='_'+toMrkdwn(n)+'_';
    else if(n.nodeName==='S'||n.nodeName==='STRIKE'||n.nodeName==='DEL')s+='~'+toMrkdwn(n)+'~';
    else if(n.nodeName==='CODE')s+='\`'+toMrkdwn(n)+'\`';
    else if(n.nodeName==='DIV'||n.nodeName==='P')s+=(s&&!s.endsWith('\\n')?'\\n':'')+toMrkdwn(n);
    else s+=toMrkdwn(n);
  }
  return s;
}
async function send(){
  const text=toMrkdwn(ed).trim();
  if(!text){st.textContent='Message is empty.';return}
  btn.disabled=true;st.textContent='Sending…';
  try{
    const res=await fetch('/send',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({text,thread_ts:THREAD_TS})});
    const d=await res.json();
    if(!d.ok)throw new Error(d.error||'unknown');
    document.querySelector('.box').style.display='none';
    const ok=document.getElementById('ok');ok.style.display='block';
    if(d.slack_url){window.location.href=d.slack_url}
    st.textContent='';
    btn.disabled=true;
    setTimeout(()=>fetch('/close'),1500);
  }catch(e){st.textContent='Error: '+e.message;btn.disabled=false}
}
</script>
</body>
</html>`;
}

// ── send ──────────────────────────────────────────────────────────

async function cmdSend(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  const text = positional.slice(2).join(" ");
  if (!target || !text) usage("Usage: slack-cli message send <channel|url> <text>");

  const parsed = parseSlackUrl(target);
  const body: Record<string, unknown> = { text };

  if (parsed) {
    body.channel = parsed.channel;
    body.thread_ts = parsed.threadTs ?? parsed.ts;
  } else {
    body.channel = await resolveChannel(target, auth);
    if (flags["thread-ts"]) body.thread_ts = flags["thread-ts"];
  }

  const result = await slackPost<{ channel: string; ts: string }>(
    "chat.postMessage",
    body,
    auth,
  );
  const messageUrl =
    `${auth.workspaceUrl}/archives/${result.channel}/p${result.ts.replace(".", "")}`;
  output({ ok: true, ts: result.ts, channel: result.channel, message_url: messageUrl });
}

// ── edit ──────────────────────────────────────────────────────────

async function cmdEdit(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  const text = positional.slice(2).join(" ");
  if (!target || !text) usage("Usage: slack-cli message edit <url|channel --ts ts> <text>");

  const { channel, ts } = await resolveMessageTarget(
    target, flags["ts"] as string | undefined, auth,
  );
  const result = await slackPost("chat.update", { channel, ts, text }, auth);
  output(result);
}

// ── delete ────────────────────────────────────────────────────────

async function cmdDelete(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  if (!target) usage("Usage: slack-cli message delete <url|channel --ts ts>");

  const { channel, ts } = await resolveMessageTarget(
    target, flags["ts"] as string | undefined, auth,
  );
  const result = await slackPost("chat.delete", { channel, ts }, auth);
  output(result);
}

// ── react ─────────────────────────────────────────────────────────

async function cmdReact(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const action = positional[1];
  const target = positional[2];
  const emoji = positional[3];
  if (!action || !target || !emoji) {
    usage("Usage: slack-cli message react <add|remove> <url|channel --ts ts> <emoji>");
  }

  const { channel, ts } = await resolveMessageTarget(
    target, flags["ts"] as string | undefined, auth,
  );
  const endpoint = action === "add" ? "reactions.add" : "reactions.remove";
  const result = await slackPost(endpoint, { channel, timestamp: ts, name: emoji }, auth);
  output(result);
}

// ── shared ────────────────────────────────────────────────────────

async function resolveChannelDisplayName(
  chanInfo: { name?: string; is_im?: boolean; user?: string } | null | undefined,
  auth: WorkspaceAuth,
): Promise<string> {
  if (!chanInfo) return "(unknown)";
  // DM channel: resolve user name
  if (chanInfo.is_im && chanInfo.user) {
    try {
      const userInfo = await slackGet<{ user?: { real_name?: string; name?: string } }>(
        "users.info", { user: chanInfo.user }, auth,
      );
      const name = userInfo.user?.real_name || userInfo.user?.name;
      if (name) return `DM: ${name}`;
    } catch { /* fall through */ }
    return `DM: ${chanInfo.user}`;
  }
  if (chanInfo.name) return `#${chanInfo.name}`;
  return "(unknown)";
}

async function resolveMessageTarget(
  target: string,
  tsFlag: string | undefined,
  auth: WorkspaceAuth,
): Promise<{ channel: string; ts: string }> {
  const parsed = parseSlackUrl(target);
  if (parsed) {
    return { channel: parsed.channel, ts: tsFlag ?? parsed.ts };
  }
  if (!tsFlag) {
    fatal(
      `--ts is required when targeting a channel by name.\n` +
      `  slack-cli message get ${target} --ts 1700000000.000000`,
    );
  }
  const channel = await resolveChannel(target, auth);
  return { channel, ts: tsFlag! };
}
