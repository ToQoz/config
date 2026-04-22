{ config, pkgs, ... }:
{
  home.packages = [ pkgs.tmux ];
  xdg.configFile."tmux".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.repoPath}/dotfiles/tmux";
}
