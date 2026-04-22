{ config, lib, ... }:
{
  home.sessionVariables.LESSHISTFILE = "${config.xdg.dataHome}/less/history";

  # less writes to LESSHISTFILE but will not create the parent directory,
  # so ensure it exists before less tries to touch it.
  home.activation.createLessHistDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.xdg.dataHome}/less"
  '';
}
