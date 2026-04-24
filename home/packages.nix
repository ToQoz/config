{
  pkgs,
  llm-agents,
  sence,
  ...
}:
{
  my.unfreePackages = [ "slack" ];

  # General-purpose CLI tools and third-party packages without a dedicated
  # module. Tool-specific installs live with their owning module (e.g.
  # `pkgs.tmux` in `tmux.nix`) to keep each module self-contained.
  home.packages = with pkgs; [
    mkcert
    wget
    tig
    ghq
    lazygit
    ripgrep
    fd
    bun
    deno
    fence
    slack
    (callPackage ../packages/portless.nix { })
    (callPackage ../packages/mo.nix { })
    (callPackage ../packages/vite-plus.nix { })
    sence.packages.${pkgs.stdenv.hostPlatform.system}.default
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.agent-browser
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.amp
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.gemini-cli
    llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
  ];
}
