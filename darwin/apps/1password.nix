{ ... }:
{
  # 1Password CLI (system-level)
  programs._1password.enable = true;
  my.unfreePackages = [ "1password-cli" ];

  # 1Password desktop (GUI + browser integration) and Safari extension
  homebrew.casks = [ "1password" ];
  homebrew.masApps."1Password for Safari" = 1569813296;

  # 1Password Chrome extension (force-installed via managed policy)
  my.chromeForceInstallExtensions = [ "aeblfdkhhhdcdjpifhhbdiojplfjncoa" ];

  # Aerospace: floating, on workspace R
  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.1password.1password";
      run = [
        "layout floating"
        "move-node-to-workspace R"
      ];
    }
  ];
}
