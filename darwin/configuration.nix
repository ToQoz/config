{ ... }:
{
  imports = [
    ./aerospace.nix
    ./apps/1password.nix
    ./apps/aqua-voice.nix
    ./apps/chatgpt.nix
    ./apps/chrome.nix
    ./apps/claude-desktop.nix
    ./apps/codex.nix
    ./apps/figma.nix
    ./apps/karabiner.nix
    ./apps/orbstack.nix
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
