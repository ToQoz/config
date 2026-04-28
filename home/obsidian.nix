{ pkgs, ... }:
{
  home.packages = [ pkgs.obsidian ];

  my.unfreePackages = [ "obsidian" ];
}
