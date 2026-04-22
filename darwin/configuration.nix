{
  lib,
  pkgs,
  ...
}:
let
  forceInstallExtensions = [
    "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
    "fmkadmapgofadopljbjfkapdkoienihi" # React Developer Tools
  ];

  chromePolicy = {
    BrowserSignin = 0;
    ExtensionSettings = {
      "*" = {
        installation_mode = "allowed";
      };
    }
    // builtins.listToAttrs (
      map (id: {
        name = id;
        value = {
          installation_mode = "force_installed";
          update_url = "https://clients2.google.com/service/update2/crx";
        };
      }) forceInstallExtensions
    );
  };

  chromePolicyPlist = pkgs.writeText "com.google.Chrome.plist" (
    lib.generators.toPlist { escape = true; } chromePolicy
  );
in
{
  imports = [
    ./fonts.nix
    ./keyboard.nix
    ./nix.nix
    ./one-password.nix
    ./pam.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "vscode"
      "cursor"
      "claude-code"
      "slack"
      "1password-cli"
    ];

  # For homebrew
  system.primaryUser = "toqoz";

  system.startup.chime = false;

  system.defaults = {
    NSGlobalDomain = {
      _HIHideMenuBar = true;
      AppleShowAllExtensions = true;
      ApplePressAndHoldEnabled = false; # For fast key repeat
      InitialKeyRepeat = 16;
      KeyRepeat = 4;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
    };

    dock = {
      autohide = true;
      show-recents = false;
      launchanim = false;
      expose-animation-duration = 0.1;
      persistent-apps = [ ];
      persistent-others = [ ];
    };

    finder = {
      # Show dotfiles
      AppleShowAllFiles = true;
      # Search Scope = cwd
      FXDefaultSearchScope = "SCcf";
      # List style
      FXPreferredViewStyle = "Nlsv";
      # Don't confirm changing file ext
      FXEnableExtensionChangeWarning = false;
      # Show filepath in title
      _FXShowPosixPathInTitle = true;
      # Don't show icons on desktop
      CreateDesktop = false;
      # Open ~
      NewWindowTarget = "Home";
    };

    screencapture = {
      target = "clipboard";
    };

    hitoolbox = {
      AppleFnUsageType = "Do Nothing";
    };

    CustomUserPreferences = {
      # WezTerm  Full Disk Access to avoid "Operation not permitted".
      "com.apple.Safari" = {
        AutoFillFromAddressBook = false;
        AutoFillPasswords = false;
        AutoFillCreditCardData = false;
        AutoFillMiscellaneousForms = false;
        AutoOpenSafeDownloads = false;
        IncludeDevelopMenu = true;
        IncludeInternalDebugMenu = true;
        WebKitDeveloperExtrasEnabledPreferenceKey = true;
        "WebKitPreferences.developerExtrasEnabled" = true;
      };

      "com.apple.TextEdit" = {
        AddExtensionToNewPlainTextFiles = false;
        ShowRuler = false;
        SmartCopyPaste = false;
        SmartDashes = false;
        SmartQuotes = false;
        RichText = false;
        TextReplacement = false;
      };

      "com.openai.chat" = {
        KeyboardShortcuts_toggleLauncher = ''{"carbonModifiers":256,"carbonKeyCode":49}''; # Option+Space

        KeyboardShortcuts_toggleAttachedLauncher = ''{"carbonModifiers":768,"carbonKeyCode":18}''; # Option+Shift+1
      };

      # When modifying com.apple.symbolichotkeys, you may need to run
      # /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          # IME: Control+Space -> disable
          "60" = {
            enabled = false;
          };
          # Spotlight: Command+Space -> Option-Space
          "64" = {
            enabled = true;
            value = {
              type = "standard";
              parameters = [
                32
                49
                524288
              ]; # Option+Space
            };
          };
        };
      };
    };
  };

  services.aerospace = {
    enable = true;
    settings = {
      config-version = 2;

      exec = {
        inherit-env-vars = true;
        env-vars = {
          PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:/Users/toqoz/.nix-profile/bin:/etc/profiles/per-user/toqoz/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
      };

      after-startup-command = [
        "exec-and-forget sketchybar"
      ];

      # (managed by home-manager)
      start-at-login = false;

      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;

      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";

      on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

      exec-on-workspace-change = [
        "/bin/bash"
        "-c"
        "sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$(/run/current-system/sw/bin/aerospace list-workspaces --focused)"
      ];

      automatically-unhide-macos-hidden-apps = false;

      persistent-workspaces = [
        "1"
        "2"
        "3"
        "4"
        "5"
        "Q"
        "W"
        "E"
        "R"
        "T"
      ];

      on-mode-changed = [ ];

      key-mapping.preset = "qwerty";

      gaps = {
        inner = {
          horizontal = 8;
          vertical = 8;
        };
        outer = {
          left = 8;
          bottom = 8;
          top = [
            { monitor."Studio Display" = 40; }
            4
          ];
          right = 8;
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

        alt-tab = "focus dfs-next --boundaries-action wrap-around-the-workspace";
        alt-shift-tab = "focus dfs-prev --boundaries-action wrap-around-the-workspace";

        alt-minus = "resize smart -50";
        alt-equal = "resize smart +50";

        alt-1 = "workspace 1";
        alt-2 = "workspace 2";
        alt-3 = "workspace 3";
        alt-4 = "workspace 4";
        alt-5 = "workspace 5";

        alt-q = "workspace Q";
        alt-w = "workspace W";
        alt-e = "workspace E";
        alt-r = "workspace R";
        alt-t = "workspace T";

        alt-shift-1 = "move-node-to-workspace 1";
        alt-shift-2 = "move-node-to-workspace 2";
        alt-shift-3 = "move-node-to-workspace 3";
        alt-shift-4 = "move-node-to-workspace 4";
        alt-shift-5 = "move-node-to-workspace 5";

        alt-shift-q = "move-node-to-workspace Q";
        alt-shift-w = "move-node-to-workspace W";
        alt-shift-e = "move-node-to-workspace E";
        alt-shift-r = "move-node-to-workspace R";
        alt-shift-t = "move-node-to-workspace T";

        # alt-tab = "workspace-back-and-forth";
        # alt-shift-tab = "move-workspace-to-monitor --wrap-around next";

        alt-shift-semicolon = "mode service";
      };

      workspace-to-monitor-force-assignment = {
        "1" = "main";
        "2" = "main";
        "3" = "main";
        "4" = "secondary";
        "5" = "secondary";
        "Q" = "main";
        "W" = "main";
        "E" = "main";
        "R" = "secondary";
        "T" = "secondary";
      };

      on-window-detected = [
        {
          "if".app-id = "com.github.wez.wezterm";
          run = [ "move-node-to-workspace 1" ];
        }
        {
          "if".app-id = "com.openai.codex";
          run = [ "move-node-to-workspace 2" ];
        }
        {
          "if".app-id = "org.google.Chrome";
          run = [ "move-node-to-workspace 3" ];
        }
        {
          "if".app-id = "dev.kdrag0n.MacVirt"; # OrbStack
          run = [
            "layout floating"
            "move-node-to-workspace 4"
          ];
        }
        {
          "if".app-id = "com.electron.aqua-voice";
          run = [
            "layout floating"
          ];
        }
        {
          "if".app-id = "com.apple.Safari";
          run = [ "move-node-to-workspace Q" ];
        }
        {
          "if".app-id = "com.openai.chat";
          run = [
            "move-node-to-workspace W"
            "layout accordion"
          ];
        }
        {
          "if".app-id = "com.anthropic.claudefordesktop";
          run = [
            "move-node-to-workspace W"
            "layout accordion"
          ];
        }
        {
          "if".app-id = "com.tinyspeck.slackmacgap";
          run = [ "move-node-to-workspace Q" ];
        }
        {
          "if".app-id = "com.figma.Desktop";
          run = [ "move-node-to-workspace E" ];
        }
        {
          "if".app-id = "com.apple.systempreferences";
          run = [
            "layout floating"
            "move-node-to-workspace R"
          ];
        }
        {
          "if".app-id = "org.pqrs.Karabiner-EventViewer";
          run = [
            "layout floating"
            "move-node-to-workspace R"
          ];
        }
        {
          "if".app-id = "com.1password.1password";
          run = [
            "layout floating"
            "move-node-to-workspace R"
          ];
        }
        {
          "if".app-id = "com.apple.Music";
          run = [
            "layout floating"
            "move-node-to-workspace R"
          ];
        }
      ];

      mode.service.binding = {
        esc = [
          "reload-config"
          "mode main"
        ];
        r = [
          "flatten-workspace-tree"
          "mode main"
        ];
        f = [
          "layout floating tiling"
          "mode main"
        ];
        backspace = [
          "close-all-windows-but-current"
          "mode main"
        ];

        alt-shift-h = [
          "join-with left"
          "mode main"
        ];
        alt-shift-j = [
          "join-with down"
          "mode main"
        ];
        alt-shift-k = [
          "join-with up"
          "mode main"
        ];
        alt-shift-l = [
          "join-with right"
          "mode main"
        ];
      };
    };
  };
  # Disable auto-restart so that when AeroSpace loses its accessibility permission
  # after an update (e.g. codesign certificate renewal), it won't spin in a crash loop
  # before you re-grant the permission in System Settings.
  #
  # To start manually after granting accessibility permission:
  # $ launchctl start org.nixos.aerospace
  launchd.user.agents.aerospace.serviceConfig.KeepAlive = lib.mkForce false;

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall";
    };

    casks = [
      "google-chrome"
      "1password"
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

    masApps = {
      "1Password for Safari" = 1569813296;
    };
  };

  system.activationScripts.postActivation.text = ''
    # Install Chrome Managed Policy
    install -d -m 0755 "/Library/Managed Preferences"
    install -m 0644 "${chromePolicyPlist}" "/Library/Managed Preferences/com.google.Chrome.plist"
    chown root:wheel "/Library/Managed Preferences/com.google.Chrome.plist"
  '';
}
