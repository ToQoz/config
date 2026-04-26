{
  lib,
  fetchurl,
  stdenv,
  unzip,
}:
let
  version = "0.4.0";
  inherit (stdenv.hostPlatform) system;
  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/k1LoW/tcmux/releases/download/v${version}/tcmux_v${version}_darwin_arm64.zip";
      hash = "sha256-04btXRxf7Rc+0iS26izob/qAKagQz2epeX0BfA4XReU=";
    };
  };
  src = sources.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation {
  inherit version;
  pname = "tcmux";

  src = fetchurl {
    inherit (src) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/bin
    cp tcmux $out/bin/tcmux
  '';

  meta = with lib; {
    description = "Terminal and coding agent mux viewer for tmux";
    homepage = "https://github.com/k1LoW/tcmux";
    license = licenses.mit;
    mainProgram = "tcmux";
    platforms = builtins.attrNames sources;
  };
}
