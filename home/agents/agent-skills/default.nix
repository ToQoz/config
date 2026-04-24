{ pkgs, anthropic-skills, vercel-agent-browser, ... }:

let
  # Real soffice CLI binary. On darwin, nixpkgs' `libreoffice-bin` ships the
  # LibreOffice.app bundle and a $out/bin/soffice *wrapper* that just runs
  # `open -na` — async and headless-unfriendly. Point at the real binary
  # inside the app bundle so subprocess calls behave synchronously.
  sofficePath =
    if pkgs.stdenv.isDarwin then
      "${pkgs.libreoffice-bin}/Applications/LibreOffice.app/Contents/MacOS/soffice"
    else
      "${pkgs.libreoffice}/bin/soffice";

  xlsxSoffice = pkgs.writeShellScriptBin "soffice" ''
    exec "${sofficePath}" "$@"
  '';

  # Dependency-complete python for the xlsx skill. pandas/openpyxl/defusedxml/
  # lxml satisfy the skill's imports; soffice on PATH satisfies recalc.py's
  # subprocess call.
  xlsxPython = pkgs.writeShellScriptBin "python" ''
    export PATH=${xlsxSoffice}/bin:$PATH
    exec ${pkgs.python3.withPackages (ps: with ps; [
      pandas
      openpyxl
      defusedxml
      lxml
    ])}/bin/python3 "$@"
  '';
in
{
  programs.agent-skills = {
    enable = true;
    sources = {
      local = {
        path = ../skills;
        filter.maxDepth = 1;
      };
      anthropic = {
        path = anthropic-skills;
        subdir = "skills";
        # Exclude xlsx so the allowlisted copy doesn't collide with the
        # explicit wrapped variant below. Regex matches any string except
        # exactly "xlsx": length != 4, or a 4-char string that differs from
        # "xlsx" in at least one position.
        filter.nameRegex = "^(.{0,3}|.{5,}|[^x]...|x[^l]..|xl[^s].|xls[^x])$";
      };
      vercel = {
        path = vercel-agent-browser;
        subdir = "skills";
      };
    };
    skills = {
      enableAll = [
        "local"
        "anthropic"
        "vercel"
      ];
      # Wrap xlsx so its Python deps (pandas/openpyxl/defusedxml/lxml) and
      # LibreOffice come from nix, not from system-wide installs. The
      # transform rewrites `python ...` invocations in SKILL.md to `./python
      # ...` so the agent picks up the bundled wrapper.
      explicit.xlsx = {
        from = "anthropic";
        path = "xlsx";
        packages = [ xlsxPython ];
        transform =
          { original, dependencies }:
          let
            patched = builtins.replaceStrings
              [
                "`python "
                "\npython "
                "  python "
                "| python "
                "&& python "
              ]
              [
                "`./python "
                "\n./python "
                "  ./python "
                "| ./python "
                "&& ./python "
              ]
              original;
          in
          ''
            ${patched}

            ${dependencies}
          '';
      };
    };
    targets.agents.enable = true;
    targets.claude.enable = true;
  };
}
