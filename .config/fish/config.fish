# disable greeting messages
set fish_greeting

if status is-interactive
    # Commands to run in interactive sessions can go here
end

alias vim="nvim"
alias ssh="env TERM=xterm-256color ssh"

function idea
  command idea $argv > /dev/null 2>&1 &
  disown
end
function xdg-open
  command xdg-open $argv > /dev/null 2>&1 &
  disown
end

# Git
set __fish_git_prompt_showdirtystate 'yes'
set __fish_git_prompt_showstashstate 'yes'
set __fish_git_prompt_showuntrackedfiles 'yes'
set __fish_git_prompt_showupstream 'yes'
set __fish_git_prompt_color_branch white
set __fish_git_prompt_color_upstream_ahead green
set __fish_git_prompt_color_upstream_behind red
set __fish_git_prompt_char_dirtystate '[dirty]'
set __fish_git_prompt_char_stagedstate '[staged]'
set __fish_git_prompt_char_untrackedfiles '[untracked]'
set __fish_git_prompt_char_stashstate '[stashed]'
set __fish_git_prompt_char_upstream_ahead '[+]'
set __fish_git_prompt_char_upstream_behind '[-]'

function fish_user_key_bindings
  bind \cr  select_history
  bind \cxg select_repository
end

eval (direnv hook fish)
