{ lib, ... }:
{
  options.my.unfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Unfree package names this user's home-manager config needs. These
      are pooled with the system-level list into
      `nixpkgs.config.allowUnfreePredicate` by `darwin/unfree.nix`, so
      each home-manager module can declare its own unfree dependencies
      next to the package it installs.
    '';
  };
}
