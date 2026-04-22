{ ... }:
{
  # Homebrew enablement + global activation policy. Concrete installs
  # (casks, masApps) live with their owning modules — darwin/apps/<app>.nix
  # for apps, darwin/fonts.nix for fonts — and merge in from there.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };
  };
}
