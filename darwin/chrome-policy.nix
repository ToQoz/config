{ config, lib, pkgs, ... }:
let
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
      }) config.my.chromeForceInstallExtensions
    );
  };

  chromePolicyPlist = pkgs.writeText "com.google.Chrome.plist" (
    lib.generators.toPlist { escape = true; } chromePolicy
  );
in
{
  options.my.chromeForceInstallExtensions = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Chrome extension IDs to force-install via the managed-policy plist.
      Each owning app module should append its extension ID here so the
      install is declared alongside the app it belongs to.
    '';
  };

  config = {
    # Seeded with the current set; per-app modules will take over their
    # entries in follow-up commits.
    my.chromeForceInstallExtensions = [
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
      "fmkadmapgofadopljbjfkapdkoienihi" # React Developer Tools
    ];

    system.activationScripts.postActivation.text = ''
      # Install Chrome Managed Policy
      install -d -m 0755 "/Library/Managed Preferences"
      install -m 0644 "${chromePolicyPlist}" "/Library/Managed Preferences/com.google.Chrome.plist"
      chown root:wheel "/Library/Managed Preferences/com.google.Chrome.plist"
    '';
  };
}
