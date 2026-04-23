{ ... }:
{
  my.apps.codex.appId = "com.openai.codex";

  # The GUI desktop app still comes from Homebrew.
  # The terminal CLI is installed via `llm-agents` in Home Manager.
  homebrew.casks = [
    "codex-app"
  ];
}
