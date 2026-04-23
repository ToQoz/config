{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    vscode
    code-cursor
    zed-editor
  ];

  my.unfreePackages = [
    "vscode"
    "cursor"
  ];

  home.file."Library/Application Support/Cursor/User/settings.json".source =
    lib.mkIf pkgs.stdenv.isDarwin (
      config.lib.file.mkOutOfStoreSymlink
        "${config.my.repoPath}/home-manager/vscode-family/cursor-settings.jsonc"
    );
}
