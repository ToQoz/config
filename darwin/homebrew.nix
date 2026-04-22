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
      "karabiner-elements"
      "macskk"
      "aqua-voice"
      "nani"
      "orbstack"
      "figma"
      "font-sketchybar-app-font"
      "claude"
      "codex"
      "codex-app"
    ];

    masApps = { };
  };
}
