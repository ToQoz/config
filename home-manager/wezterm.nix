{ config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/src/github.com/ToQoz/config/dotfiles";
in
{
  programs.wezterm = {
    enable = true;
  };
  xdg.configFile."wezterm".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/wezterm";
}
