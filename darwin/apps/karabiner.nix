{ ... }:
{
  homebrew.casks = [ "karabiner-elements" ];

  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "org.pqrs.Karabiner-EventViewer";
      run = [
        "layout floating"
        "move-node-to-workspace R"
      ];
    }
  ];
}
