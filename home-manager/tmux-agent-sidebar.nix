{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
}:
let
  version = "0.7.1";

  bins = {
    aarch64-darwin = fetchurl {
      url = "https://github.com/hiroppy/tmux-agent-sidebar/releases/download/v${version}/tmux-agent-sidebar-darwin-aarch64";
      hash = "sha256:12crm23ga7zdbqk1c4fz2c85636df1cqh10i1cw0pmhkqq51y0m4";
    };
    x86_64-darwin = fetchurl {
      url = "https://github.com/hiroppy/tmux-agent-sidebar/releases/download/v${version}/tmux-agent-sidebar-darwin-x86_64";
      hash = "sha256:04hd41p5j1fz2n9hcp6gcydz6l4hfpf4w0wi4fza80ggml5vv3vk";
    };
  };
in
stdenv.mkDerivation {
  pname = "tmux-agent-sidebar";
  inherit version;

  src = fetchFromGitHub {
    owner = "hiroppy";
    repo = "tmux-agent-sidebar";
    rev = "v${version}";
    hash = "sha256-NSRSGRy/VMpJh/NcUDBMvyjIz5PAybRhKi4NK3D2m5c=";
  };

  installPhase = ''
    mkdir -p $out/bin $out/share/tmux-plugins/tmux-agent-sidebar

    # Pre-built binary
    install -m 755 ${bins.${stdenv.hostPlatform.system}} $out/bin/tmux-agent-sidebar
  '';

  meta = with lib; {
    description = "tmux sidebar for monitoring AI coding agents";
    homepage = "https://github.com/hiroppy/tmux-agent-sidebar";
    license = licenses.mit;
    mainProgram = "tmux-agent-sidebar";
  };
}
