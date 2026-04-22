{ ... }:
{
  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.apple.systempreferences";
      run = [
        "layout floating"
        "move-node-to-workspace R"
      ];
    }
  ];
}
