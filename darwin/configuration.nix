{ ... }:
{
  imports = [
    ./aerospace.nix
    ./apps/1password.nix
    ./apps/chatgpt.nix
    ./apps/chrome.nix
    ./defaults.nix
    ./fonts.nix
    ./homebrew.nix
    ./keyboard.nix
    ./nix.nix
    ./pam.nix
    ./unfree.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  # For homebrew
  system.primaryUser = "toqoz";

  system.startup.chime = false;
}
