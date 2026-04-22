{ ... }:
{
  my.apps.chatgpt.appId = "com.openai.chat";

  homebrew.casks = [ "chatgpt" ];

  system.defaults.CustomUserPreferences."com.openai.chat" = {
    KeyboardShortcuts_toggleLauncher = ''{"carbonModifiers":256,"carbonKeyCode":49}''; # Option+Space

    KeyboardShortcuts_toggleAttachedLauncher = ''{"carbonModifiers":768,"carbonKeyCode":18}''; # Option+Shift+1
  };
}
