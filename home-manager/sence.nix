{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
}:
stdenv.mkDerivation {
  pname = "sence";
  version = "0.1.0-unstable-2026-04-20";

  src = fetchFromGitHub {
    owner = "toqoz";
    repo = "sence";
    rev = "7ef1d6b335939339dfa259e48a5e12b0cddbe0f9";
    hash = "sha256-PVK/Vx+To6qgNoEjVXbOJ43w1jniH1n24oovM8Qo4bg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/sence
    cp -r bin src docs $out/share/sence/

    makeWrapper ${nodejs}/bin/node $out/bin/sence \
      --add-flags $out/share/sence/bin/sence

    runHook postInstall
  '';

  meta = with lib; {
    description = "A thin fence wrapper that suggests policy refinements";
    homepage = "https://github.com/toqoz/sence";
    license = licenses.mit;
    mainProgram = "sence";
  };
}
