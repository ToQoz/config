{
  lib,
  config,
  ...
}:
let
  root = "${config.home.homeDirectory}/src/github.com/ToQoz/config";
in
{
  imports = [
    ./agents/agent-skills.nix
    ./agents/claude-code.nix
    ./agents/mcp.nix
    ./android.nix
    ./asdf.nix
    ./direnv.nix
    ./fzf.nix
    ./gh.nix
    ./git.nix
    ./neovim.nix
    ./nix.nix
    ./packages.nix
    ./sketchybar.nix
    ./starship.nix
    ./tmux.nix
    ./unfree.nix
    ./vscode-family.nix
    ./wezterm.nix
    ./zsh.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "toqoz";
  home.homeDirectory = "/Users/toqoz";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.11"; # Please read the comment before changing.

  home.sessionVariables = {
    XDG_DATA_HOME = config.xdg.dataHome; # for .tig_history
    # EDITOR = "emacs";
    Z_DATA_DIR = "${config.xdg.dataHome}/zsh";
    Z_CACHE_DIR = "${config.xdg.cacheHome}/zsh";
    LESSHISTFILE = "${config.xdg.dataHome}/less/history";
    WGETHSTS = "${config.xdg.cacheHome}/wget/hsts";
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.scripts"
  ];

  # local scripts
  home.file.".scripts".source = config.lib.file.mkOutOfStoreSymlink "${root}/scripts";
  home.activation.createXdgDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # less requires the parent directory to exist before it can write LESSHISTFILE
    mkdir -p "${config.xdg.dataHome}/less"
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
