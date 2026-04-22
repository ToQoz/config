{ config, lib, ... }:
{
  options.my.unfreePackages = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Unfree package names the darwin-level config needs. Pooled with the
      home-manager user's `my.unfreePackages` list to build a single
      `nixpkgs.config.allowUnfreePredicate`, so each module — whether
      darwin or home-manager — can declare its own unfree dependencies
      next to the package it installs.
    '';
  };

  config.nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) (
      config.my.unfreePackages
      ++ (config.home-manager.users.toqoz.my.unfreePackages or [ ])
    );

  # Seed the darwin list with the full set for now; individual modules will
  # adopt their own entries in follow-up commits, shrinking this list to
  # only the darwin-owned names.
  config.my.unfreePackages = [
    "vscode"
    "cursor"
    "claude-code"
    "slack"
    "1password-cli"
  ];
}
