{ ... }:
{
  imports = [
    ./aerospace.nix
    ./chrome-policy.nix
    ./defaults.nix
    ./fonts.nix
    ./homebrew.nix
    ./keyboard.nix
    ./nix.nix
    ./one-password.nix
    ./pam.nix
    ./unfree.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  # For homebrew
  system.primaryUser = "toqoz";

  system.startup.chime = false;
}
