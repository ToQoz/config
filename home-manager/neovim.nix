{ config, lib, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/src/github.com/ToQoz/config/dotfiles";
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withRuby = false;
    withPython3 = false;
    sideloadInitLua = true;

    # mkAfter: when this module was inlined in home.nix, HM's internal
    # additions to extraWrapperArgs (for sideloadInitLua) preceded the
    # user's. Splitting into a separate module reverses that order because
    # list merging follows module evaluation order. mkAfter restores it.
    extraWrapperArgs = lib.mkAfter [
      "--set"
      "TELESCOPE_FZY_NATIVE"
      "${pkgs.vimPlugins.telescope-fzy-native-nvim}"
    ];

    extraPackages = with pkgs; [
      skkDictionaries.l
      lua-language-server
      typescript-language-server
      nixd # Nix Language Server
      bash-language-server
      vim-language-server
      emmet-language-server
      stylua # Lua formatter
      nixfmt
      vimPlugins.telescope-fzy-native-nvim # To avoid build steps
    ];
  };

  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/nvim";
}
