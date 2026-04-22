{ config, lib, pkgs, ... }:
{
  home.packages = lib.optionals pkgs.stdenv.isDarwin [ pkgs.sketchybar ];

  xdg.configFile."sketchybar".source = lib.mkIf pkgs.stdenv.isDarwin (
    config.lib.file.mkOutOfStoreSymlink "${config.my.repoPath}/dotfiles/sketchybar"
  );
}
