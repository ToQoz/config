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

  # Seed the darwin list with the remaining entries not yet adopted by an
  # owning module. As modules take over their own entries this list
  # shrinks.
  config.my.unfreePackages = [
    "slack"
  ];
}
