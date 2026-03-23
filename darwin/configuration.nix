{
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  nix.enable = false;
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  # For homebrew
  system.primaryUser = "toqoz";

  homebrew = {
    enable = true;

    casks = [
      "karabiner-elements"
    ];
  };
}
