{ ... }:
{
  homebrew.casks = [ "orbstack" ];

  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "dev.kdrag0n.MacVirt"; # OrbStack
      run = [
        "layout floating"
        "move-node-to-workspace 4"
      ];
    }
  ];
}
