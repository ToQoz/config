{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };

    # Concrete cask/masApp installs live with their owning module
    # (darwin/apps/<app>.nix for apps, darwin/fonts.nix for fonts).
    # This list stays empty; entries merge in from elsewhere.
    casks = [
      "font-sketchybar-app-font"
    ];

    masApps = { };
  };
}
