{ ... }:
{
  my.apps.codex.appId = "com.openai.codex";

  # "codex" is the terminal CLI cask; "codex-app" is the GUI desktop app.
  # They ship as separate casks but share the same app-id for aerospace.
  homebrew.casks = [
    "codex"
    "codex-app"
  ];
}
