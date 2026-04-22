{ ... }:
{
  homebrew.casks = [ "figma" ];

  services.aerospace.settings.on-window-detected = [
    {
      "if".app-id = "com.figma.Desktop";
      run = [ "move-node-to-workspace E" ];
    }
  ];
}
