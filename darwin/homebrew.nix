{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };

    # Single-concern casks without a dedicated app module. Apps that have
    # any additional config (aerospace rules, defaults, etc.) live in
    # darwin/apps/<app>.nix and contribute their own cask there.
    casks = [
      "macskk"
      "nani"
      "font-sketchybar-app-font"
    ];

    masApps = { };
  };
}
