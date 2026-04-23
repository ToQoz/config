{ config, lib, ... }:
{
  # Environment variables for small tools that have no dedicated module
  # and whose only customization is "stop writing to $HOME; honor XDG".
  #
  # If any of these tools later grows a real config surface, move that
  # tool out to its own module.
  home.sessionVariables = {
    # Many XDG-aware tools (tig, yazi, fd, ...) check this. Home Manager's
    # xdg.dataHome is the canonical value but is not exported by default
    # when xdg.enable is off.
    XDG_DATA_HOME = config.xdg.dataHome;

    LESSHISTFILE = "${config.xdg.dataHome}/less/history";

    WGETHSTS = "${config.xdg.cacheHome}/wget/hsts";
  };

  # less will not create the parent directory for LESSHISTFILE on first
  # write, so ensure it exists.
  home.activation.createLessHistDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.xdg.dataHome}/less"
  '';
}
