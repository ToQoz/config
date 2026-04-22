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
    ./apps/music.nix
    ./apps/orbstack.nix
    ./apps/safari.nix
    ./apps/slack.nix
    ./apps/system-preferences.nix
    ./apps/wezterm.nix
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
