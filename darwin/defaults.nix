{ ... }:
{
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
      "com.apple.TextEdit" = {
        AddExtensionToNewPlainTextFiles = false;
        ShowRuler = false;
        SmartCopyPaste = false;
        SmartDashes = false;
        SmartQuotes = false;
        RichText = false;
        TextReplacement = false;
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
}
