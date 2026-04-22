{ config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/src/github.com/ToQoz/config/dotfiles";
in
{
  programs.starship = {
    enable = true;
  };
  # ref. https://github.com/starship/starship/issues/896
  xdg.configFile."starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/starship/config.toml";
}
