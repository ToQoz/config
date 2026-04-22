{ pkgs, ... }:
{
  # Nix-provided fonts — fast to install, reproducibly pinned.
  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  # Homebrew-only fonts. Kept here, not in homebrew.nix, so all fonts
  # live together regardless of how they're delivered. sketchybar
  # requires this specific icon font at runtime.
  homebrew.casks = [
    "font-sketchybar-app-font"
  ];
}
