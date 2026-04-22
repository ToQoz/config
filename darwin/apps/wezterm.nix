{ ... }:
{
  # WezTerm is installed and configured on the home-manager side
  # (programs.wezterm in home-manager/wezterm.nix). This file exists
  # so aerospace can reference the bundle ID by semantic name.
  my.apps.wezterm.appId = "com.github.wez.wezterm";
}
