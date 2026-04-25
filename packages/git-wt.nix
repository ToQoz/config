{
  lib,
  fetchurl,
  stdenv,
  unzip,
}:
let
  version = "0.27.0";
  inherit (stdenv.hostPlatform) system;
  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/k1LoW/git-wt/releases/download/v${version}/git-wt_v${version}_darwin_arm64.zip";
      hash = "sha256-uu4zuUgTsC+nxGrt7fVpxgV92GeJ86Ocgd8bgCotMx4=";
    };
  };
  src = sources.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation {
  inherit version;
  pname = "git-wt";

  src = fetchurl {
    inherit (src) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    mkdir -p $out/bin
    cp git-wt $out/bin/git-wt
  '';

  meta = with lib; {
    description = "Git subcommand that makes worktrees simple";
    homepage = "https://github.com/k1LoW/git-wt";
    license = licenses.mit;
    mainProgram = "git-wt";
    platforms = builtins.attrNames sources;
  };
}
