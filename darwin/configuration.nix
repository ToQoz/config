{
  lib,
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  nix.enable = false;
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "1password-cli"
  ];

  # For homebrew
  system.primaryUser = "toqoz";

  programs = {
    # 1Password CLI
    _1password.enable = true;
  };

  homebrew = {
    enable = true;

    casks = [
      "1password"
      "karabiner-elements"
    ];
  };
}
