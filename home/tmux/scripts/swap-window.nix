# `prefix H` / `prefix L`: swap the current window left or right. No-op
# (and exits 0) when already at the left edge so `-r` repeat presses
# don't blow up.
#
# `tmux` is injected so tests can pass a fake.
{ pkgs, tmux }:
pkgs.writeShellScriptBin "tmux-swap-window" ''
  set -eu
  case "''${1:-}" in
    left | right) ;;
    *)
      echo "usage: tmux-swap-window <left|right>" >&2
      exit 2
      ;;
  esac
  cw=$(${tmux}/bin/tmux display-message -p '#I')
  case "$1" in
    left)
      [ "$cw" -gt 0 ] || exit 0
      ${tmux}/bin/tmux swap-window -s "$cw" -t "$((cw - 1))"
      ;;
    right)
      ${tmux}/bin/tmux swap-window -s "$cw" -t "$((cw + 1))"
      ;;
  esac
''
