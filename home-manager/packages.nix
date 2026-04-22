{
  lib,
  pkgs,
  llm-agents,
  sence,
  ...
}:
let
  # Temporary version bump for `fence`.
  #
  # nixpkgs (as of this writing) ships fence 0.1.46, but we want 0.1.48 to
  # pick up upstream fixes. Once nixpkgs catches up to >= 0.1.48, delete this
  # override and restore the plain `fence` line in `home.packages`.
  #
  # Approach: inline `overrideAttrs` on `pkgs.fence`, bumping `version`, `src`,
  # and `vendorHash`. We intentionally avoid a full `nixpkgs.overlays` entry —
  # this flake sets `home-manager.useGlobalPkgs = true`, so overlays must live
  # at the nix-darwin level. A scoped override keeps the change local to its
  # one call site and trivial to delete.
  #
  # Note the two-argument form `(finalAttrs: _prevAttrs: ...)`: the upstream
  # definition (`pkgs/by-name/fe/fence/package.nix`) derives `src` from
  # `finalAttrs.version` via the `buildGoModule` fixed-point, so the new
  # version must be visible through `finalAttrs`. The single-arg form would
  # leave `src` pointing at v0.1.46.
  #
  # To refresh the hashes when bumping further:
  #   nix-prefetch-url --unpack https://github.com/Use-Tusk/fence/archive/refs/tags/vX.Y.Z.tar.gz
  #   nix hash to-sri --type sha256 <hash>        # -> src hash
  # For `vendorHash`, set it to `lib.fakeHash` (or any wrong value), run the
  # build, and copy the "got:" hash from the error.
  fence-0_1_48 = pkgs.fence.overrideAttrs (
    finalAttrs: _prevAttrs: {
      version = "0.1.48";
      src = pkgs.fetchFromGitHub {
        owner = "Use-Tusk";
        repo = "fence";
        tag = "v${finalAttrs.version}";
        hash = "sha256-OBbN/mSoQfpeBMl3KYD+fLVwB/ruux9jvk9HJjDmxU8=";
      };
      vendorHash = "sha256-Zfrst8fQNHP3KNpTQLIju9qo2hyozOWwbdNw0qCGhJ0=";
    }
  );
in
{
  # The home.packages option allows you to install Nix packages into your
  # environment.
  #
  # mkAfter: when this block lived in home.nix, user packages were appended
  # after HM's internal contributions (program modules, session vars, etc.)
  # in the final home-manager-path pkgs list. Splitting into a separate
  # module reverses the merge order. mkAfter restores it so the resulting
  # derivation stays bit-identical.
  home.packages = lib.mkAfter (
    with pkgs;
    [
      mkcert
      wget
      tmux
      tig
      ghq
      lazygit
      ripgrep
      fd
      bun
      deno
      # fence  # re-enable once nixpkgs ships >= 0.1.48; see `fence-0_1_48` override in `let` block above
      fence-0_1_48
      asdf-vm
      vscode
      code-cursor
      zed-editor
      slack
      (callPackage ../packages/portless.nix { })
      (callPackage ../packages/mo.nix { })
      (callPackage ../packages/vite-plus.nix { })
      (callPackage ../packages/pi-coding-agent.nix { })
      sence.packages.${pkgs.stdenv.hostPlatform.system}.default
      llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      pkgs.sketchybar
    ]
  );
}
