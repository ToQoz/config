{ ... }:
{
  my.apps.safari.appId = "com.apple.Safari";

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
}
