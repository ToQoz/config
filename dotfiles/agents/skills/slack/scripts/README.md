# Scripts for slack skill

## slack-cli - Slack CLI script

Inspired by [stablyai/agent-slack](https://github.com/stablyai/agent-slack).
Built from scratch for different goals:

- **Zero dependencies** — no `@slack/web-api`, Commander, Zod, or native modules; runs directly with `node --experimental-transform-types`
- **Compact surface** — only the commands I actually use, in ~8 source files
- **Fewer password prompts** — all Keychain secrets stored in a single entry so `auth import-desktop` triggers at most one macOS prompt
- **Full control** — a Slack skill acts on my behalf with strong privileges; I want to own and audit every line
