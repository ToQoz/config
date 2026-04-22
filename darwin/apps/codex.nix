{ ... }:
{
  # "codex" is the terminal CLI cask; "codex-app" is the GUI desktop app.
  # They ship as separate casks but share the same app-id for aerospace.
  homebrew.casks = [
    "codex"
    "codex-app"
  ];

  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.openai.codex";
      run = [ "move-node-to-workspace 2" ];
    }
  ];
}
