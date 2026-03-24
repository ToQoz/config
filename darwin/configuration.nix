{
  lib,
  ...
}:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  nix.enable = false;
  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "1password-cli"
  ];

  # For homebrew
  system.primaryUser = "toqoz";

  services.aerospace = {
    enable = true;
    settings = {
      config-version = 2;

      after-startup-command = [ ];

      # (managed by home-manager)
      start-at-login = false;

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      automatically-unhide-macos-hidden-apps = false;

      persistent-workspaces = [
        "1" "2" "3" "4" "5" "6" "7" "8" "9"
        "A" "B" "C" "D" "E" "F" "G" "I" "M" "N" "O" "P" "Q"
        "R" "S" "T" "U" "V" "W" "X" "Y" "Z"
      ];

      on-mode-changed = [ ];

      key-mapping.preset = "qwerty";

      gaps = {
        inner = {
          horizontal = 10;
          vertical = 10;
        };
        outer = {
          left = 10;
          bottom = 10;
          top = 10;
          right = 10;
        };
      };

      mode.main.binding = {
        alt-slash = "layout tiles horizontal vertical";
        alt-comma = "layout accordion horizontal vertical";

        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";

        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";

        alt-minus = "resize smart -50";
        alt-equal = "resize smart +50";

        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";

        alt-a = "workspace A";
        alt-b = "workspace B";
        alt-c = "workspace C";

        alt-shift-1 = "move-node-to-workspace 1";
        alt-shift-2 = "move-node-to-workspace 2";
        alt-shift-3 = "move-node-to-workspace 3";
        alt-shift-4 = "move-node-to-workspace 4";
        alt-shift-5 = "move-node-to-workspace 5";

        alt-tab = "workspace-back-and-forth";
        alt-shift-tab = "move-workspace-to-monitor --wrap-around next";

        alt-shift-semicolon = "mode service";
      };

      workspace-to-monitor-force-assignment = {
        "1" = "main";
        "2" = "main";
        "3" = "main";
        "4" = "secondary";
        "5" = "secondary";
        "6" = "secondary";
      };

      on-window-detected = [
        {
          "if".app-id = "com.openai.chat";
          run = [ "move-node-to-workspace 3" ];
        }
        {
          "if".app-id = "com.anthropic.claudefordesktop";
          run = [ "move-node-to-workspace 3" ];
        }
      ];

      mode.service.binding = {
        esc = [ "reload-config" "mode main" ];
        r = [ "flatten-workspace-tree" "mode main" ];
        f = [ "layout floating tiling" "mode main" ];
        backspace = [ "close-all-windows-but-current" "mode main" ];

        alt-shift-h = [ "join-with left" "mode main" ];
        alt-shift-j = [ "join-with down" "mode main" ];
        alt-shift-k = [ "join-with up" "mode main" ];
        alt-shift-l = [ "join-with right" "mode main" ];
      };
    };
  };

  programs = {
    # 1Password CLI
    _1password.enable = true;
  };

  homebrew = {
    enable = true;

    casks = [
      "1password"
      "karabiner-elements"
      "macskk"
      "claude"
      "chatgpt"
      "codex-app"
    ];
  };
}
