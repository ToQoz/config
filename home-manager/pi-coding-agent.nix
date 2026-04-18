{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_24,
}:
let
  version = "0.67.68";
in
buildNpmPackage {
  pname = "pi-coding-agent";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha256-C2T+IeIiHhXAy5TJ3/1c+7mQGumd9BanHF2RWm6eFxc=";
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./pi-coding-agent-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-UIbTrLucNO7ucJqga3YtFvSKCXgRUS+nAavqXXfTn84=";

  nodejs = nodejs_24;

  dontNpmBuild = true;

  meta = with lib; {
    description = "Minimal terminal coding agent by Mario Zechner";
    homepage = "https://github.com/badlogic/pi-mono";
    license = licenses.mit;
    mainProgram = "pi";
  };
}
