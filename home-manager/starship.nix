{ config, ... }:
{
  programs.starship = {
    enable = true;
  };
  # ref. https://github.com/starship/starship/issues/896
  xdg.configFile."starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.repoPath}/dotfiles/starship/config.toml";
}
