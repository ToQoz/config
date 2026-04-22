{ ... }:
{
  homebrew.casks = [ "aqua-voice" ];

  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.electron.aqua-voice";
      run = [
        "layout floating"
      ];
    }
  ];
}
