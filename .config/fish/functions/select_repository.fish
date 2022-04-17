function select_repository
  select-ghq-list | read _selected
  [ -n "$_selected" ]; and builtin cd "$_selected"
  commandline -f repaint
end
