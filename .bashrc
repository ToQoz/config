# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PATH="$HOME/go/bin:$PATH"
PATH="$(ghg bin):$PATH"

source "$HOME/.k8n/commandline-tools/init.sh"

[ -z "$NO_FISH" ] && exec fish
