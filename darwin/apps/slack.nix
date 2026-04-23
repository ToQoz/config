{ ... }:
{
  # Slack itself is installed via home-manager (home.packages in
  # home/packages.nix). This file exists so aerospace can
  # reference the bundle ID by semantic name.
  my.apps.slack.appId = "com.tinyspeck.slackmacgap";
}
