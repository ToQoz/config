{ ... }:
{
  # Slack itself is installed via home-manager (home.packages in
  # home-manager/packages.nix, with my.unfreePackages handled there).
  # The aerospace workspace rule lives on the darwin side so this file
  # exists for symmetry — the "darwin view" of Slack in one place.
  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.tinyspeck.slackmacgap";
      run = [ "move-node-to-workspace Q" ];
    }
  ];
}
