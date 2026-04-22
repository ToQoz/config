{ ... }:
{
  # In a flake + direnv workflow the working tree is always dirty during development,
  # so the warning fires on every shell entry with zero informational value.
  xdg.configFile."nix/nix.conf".text = ''
    warn-dirty = false
  '';
}
