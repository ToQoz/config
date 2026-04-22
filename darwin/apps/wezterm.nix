{ ... }:
{
  # WezTerm itself is installed via home-manager (programs.wezterm in
  # home-manager/wezterm.nix). The aerospace workspace rule lives on the
  # darwin side so this file exists for symmetry — the "darwin view" of
  # WezTerm in one place.
  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.github.wez.wezterm";
      run = [ "move-node-to-workspace 1" ];
    }
  ];
}
