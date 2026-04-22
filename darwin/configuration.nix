{
  lib,
  pkgs,
  ...
}:
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
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "cursor"
      "claude-code"
      "slack"
      "1password-cli"
    ];

  # For homebrew
  system.primaryUser = "toqoz";

  system.startup.chime = false;

}
