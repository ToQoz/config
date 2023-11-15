function select_history
  history merge
  history | fzf --no-sort --exact | read line
  if test $line
    commandline $line
  else
    commandline ''
  end
end
