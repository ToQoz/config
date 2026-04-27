# `prefix w`: pick a window across all sessions via fzf, with the cursor
# pre-positioned on the current one. Takes the current
# `<session>:<idx>:` prefix as $1 — tmux substitutes the `#{...}`
# placeholders before the script runs, so the script itself never has to
# know tmux's format vocabulary. tcmux is used for its `agent_status`
# decoration in the listing.
#
# `tmux`, `tcmux`, and `fzf` are injected so tests can pass fakes.
{ pkgs, tmux, tcmux, fzf }:
pkgs.writeShellScriptBin "tmux-window-picker" ''
  set -eu
  current_prefix=''${1:?usage: tmux-window-picker <session>:<window>:}
  list=$(${tcmux}/bin/tcmux list-windows -A --color=always \
    -F '#{session_name}:#{window_index}: #{window_name} (#{window_panes} panes) #{agent_status}')
  pos=$(printf '%s\n' "$list" \
    | grep -nF -- "$current_prefix" \
    | head -n1 | cut -d: -f1) || true
  printf '%s\n' "$list" \
    | ${fzf}/bin/fzf --sync --ansi --layout reverse --tmux 80%,50% \
        --bind "start:pos(''${pos:-1})" \
    | cut -d: -f1-2 \
    | xargs ${tmux}/bin/tmux select-window -t
''
