{ config, pkgs, ... }:
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

    extraWrapperArgs = [
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

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.repoPath}/dotfiles/nvim";
}
