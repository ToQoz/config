{ config, ... }:
let
  root = "${config.home.homeDirectory}/src/github.com/ToQoz/config";
in
{
  # Expose this repo's `scripts/` directory on PATH via a stable `~/.scripts`
  # symlink. The mkOutOfStoreSymlink keeps edits live — changes to scripts/
  # take effect without rebuilding.
  home.sessionPath = [ "${config.home.homeDirectory}/.scripts" ];
  home.file.".scripts".source = config.lib.file.mkOutOfStoreSymlink "${root}/scripts";
}
