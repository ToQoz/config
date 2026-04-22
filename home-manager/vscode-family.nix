{ config, lib, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/src/github.com/ToQoz/config/dotfiles";
in
{
  home.file."Library/Application Support/Cursor/User/settings.json".source =
    lib.mkIf pkgs.stdenv.isDarwin (
      config.lib.file.mkOutOfStoreSymlink "${dotfiles}/vscode-family/cursor-settings.jsonc"
    );
}
