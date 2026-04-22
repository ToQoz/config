{ ... }:
{
  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.apple.Music";
      run = [
        "layout floating"
        "move-node-to-workspace R"
      ];
    }
  ];
}
