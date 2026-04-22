{ ... }:
{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };

    casks = [
      "google-chrome"
      "karabiner-elements"
      "macskk"
      "aqua-voice"
      "nani"
      "orbstack"
      "figma"
      "font-sketchybar-app-font"
      "claude"
      "chatgpt"
      "codex"
      "codex-app"
    ];

    masApps = { };
  };
}
