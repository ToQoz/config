{ ... }:
{
  # 1Password CLI
  programs._1password = {
    enable = true;
  };
  my.unfreePackages = [ "1password-cli" ];
}
