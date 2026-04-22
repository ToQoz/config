{ ... }:
{
  homebrew.casks = [ "claude" ];

  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.anthropic.claudefordesktop";
      run = [
        "move-node-to-workspace W"
        "layout accordion"
      ];
    }
  ];
}
