# `prefix s d` / `prefix s b`: tag the current window's name with
# `[done]` or `[back later]`, replacing any existing such prefix so
# repeated tagging doesn't stack `[done] [done] foo`.
#
# `tmux` is injected so tests can pass a fake.
{ pkgs, tmux }:
pkgs.writeShellScriptBin "tmux-window-tag" ''
  set -eu
  tag=''${1:?usage: tmux-window-tag <tag>}
  base=$(${tmux}/bin/tmux display-message -p '#W' \
    | sed -E 's/^\[(done|back later)\] //')
  ${tmux}/bin/tmux rename-window "[$tag] $base"
''
