{ ... }:
{
  system.defaults.CustomUserPreferences."com.apple.Safari" = {
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

  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.apple.Safari";
      run = [ "move-node-to-workspace Q" ];
    }
  ];
}
