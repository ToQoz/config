{ pkgs, ... }:
{
  # security.pam.services.sudo_local.touchIdAuth = true;
  environment.systemPackages = [
    pkgs.pam-reattach
  ];
  environment.etc."pam.d/sudo_local".text = ''
    # managed by nix-darwin
    auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so
    auth       sufficient     pam_tid.so
  '';
}
