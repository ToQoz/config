{ lib, pkgs, ... }:
{
  # security.pam.services.sudo_local.touchIdAuth = true;
  #
  # mkAfter: nix-darwin's internal modules contribute to
  # environment.systemPackages at default priority. When this declaration
  # was inlined in configuration.nix, pam-reattach landed after those
  # internal entries. Splitting into a separate module reverses the merge
  # order; mkAfter restores pam-reattach to the tail of the list.
  environment.systemPackages = lib.mkAfter [
    pkgs.pam-reattach
  ];
  # mkBefore: nix-darwin contributes a small header/trailer to this file's
  # text at default priority. When this declaration was inlined in
  # configuration.nix, the user text merged before that contribution;
  # splitting reverses the order, shifting a blank line to the top of the
  # resulting file. mkBefore restores the original position.
  environment.etc."pam.d/sudo_local".text = lib.mkBefore ''
    # managed by nix-darwin
    auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so
    auth       sufficient     pam_tid.so
  '';
}
