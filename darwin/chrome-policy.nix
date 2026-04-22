{ lib, pkgs, ... }:
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
  # mkBefore: the inlined block ran before nix-darwin's other postActivation
  # contributions (e.g. the home-manager activation banner). Splitting
  # reverses that order; mkBefore restores it.
  system.activationScripts.postActivation.text = lib.mkBefore ''
    # Install Chrome Managed Policy
    install -d -m 0755 "/Library/Managed Preferences"
    install -m 0644 "${chromePolicyPlist}" "/Library/Managed Preferences/com.google.Chrome.plist"
    chown root:wheel "/Library/Managed Preferences/com.google.Chrome.plist"
  '';
}
