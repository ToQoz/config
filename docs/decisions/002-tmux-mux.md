# 002. mux を tmux に戻す

- Status: Accepted
- Date: 2026-04-19
- Supersedes: [001](001-wezterm-mux.md)

## Context

- [001](001-wezterm-mux.md) で WezTerm の built-in mux を採用した
- しかし細かい操作感の違いに馴染み切れなかった
- tmux の方が既存のワークフローに合う

## Decision

mux は tmux を使う。WezTerm はシンプルな端末エミュレータとして使い、mux 機能は持たせない。

- tmux prefix: `C-t`
- WezTerm: leader キーなし、mux 系キーバインドなし

## Consequences

- 長年使い慣れた tmux の操作感をそのまま活かせる
- WezTerm の設定がシンプルになる
- Kitty keyboard protocol の恩恵は WezTerm + tmux の組み合わせでも享受できる
