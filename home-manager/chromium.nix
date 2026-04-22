{ pkgs, ... }:
{
  programs.chromium = {
    enable = true;
    # Installed via homebrew cask; skip Nix installation
    package = pkgs.emptyDirectory;
    extensions = [
      { id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa"; } # 1Password
      { id = "fmkadmapgofadopljbjfkapdkoienihi"; } # React Developer Tools
    ];
  };
}
