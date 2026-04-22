{ ... }:
{
  homebrew.casks = [ "chatgpt" ];

  system.defaults.CustomUserPreferences."com.openai.chat" = {
    KeyboardShortcuts_toggleLauncher = ''{"carbonModifiers":256,"carbonKeyCode":49}''; # Option+Space

    KeyboardShortcuts_toggleAttachedLauncher = ''{"carbonModifiers":768,"carbonKeyCode":18}''; # Option+Shift+1
  };

  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.openai.chat";
      run = [
        "move-node-to-workspace W"
        "layout accordion"
      ];
    }
  ];
}
