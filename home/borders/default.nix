{ config, lib, pkgs, ... }:
{
  home.packages = lib.optionals pkgs.stdenv.isDarwin [ pkgs.jankyborders ];

  xdg.configFile."borders".source = lib.mkIf pkgs.stdenv.isDarwin (
    config.lib.file.mkOutOfStoreSymlink "${config.my.repoPath}/home/borders/config"
  );
}
