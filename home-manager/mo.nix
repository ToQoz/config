{
  lib,
  fetchurl,
  stdenv,
  unzip,
}:
let
  version = "1.2.0";
  inherit (stdenv.hostPlatform) system;
  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_darwin_arm64.zip";
      hash = "sha256-fT4w/2qPTxMBAF/oABOhamo2Bvz2MLgBVmLBp7wH0YQ=";
    };
  };
  src = sources.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation {
  inherit version;
  pname = "mo";

  src = fetchurl {
    inherit (src) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/bin
    cp mo $out/bin/mo
  '';

  meta = with lib; {
    description = "Markdown viewer powered by browser with live-reload";
    homepage = "https://github.com/k1LoW/mo";
    license = licenses.mit;
    mainProgram = "mo";
  };
}
