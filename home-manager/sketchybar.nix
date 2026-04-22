{ config, lib, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/src/github.com/ToQoz/config/dotfiles";
in
{
  xdg.configFile."sketchybar".source = lib.mkIf pkgs.stdenv.isDarwin (
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/sketchybar"
  );
}
