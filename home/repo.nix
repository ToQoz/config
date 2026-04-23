{ config, lib, ... }:
{
  options.my.repoPath = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = "${config.home.homeDirectory}/src/github.com/ToQoz/config";
    description = ''
      Absolute path to this repo's live on-disk checkout. Used as the
      target of `mkOutOfStoreSymlink` so that edits in the checkout
      take effect without rebuilding. Modules reference this instead
      of re-deriving the path locally.
    '';
  };
}
