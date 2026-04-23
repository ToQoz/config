{
  description = "Home Manager configuration of toqoz";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agent-skills = {
      url = "github:Kyure-A/agent-skills-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    anthropic-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };
    vercel-agent-browser = {
      url = "github:vercel-labs/agent-browser";
      flake = false;
    };
    sence = {
      url = "github:toqoz/sence";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      llm-agents,
      agent-skills,
      anthropic-skills,
      vercel-agent-browser,
      sence,
      android-nixpkgs,
      ...
    }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
      mkDarwinCommand =
        {
          command,
          useSudo ? false,
        }:
        pkgs.writeShellApplication {
          name = "darwin-${command}";
          runtimeInputs = [
            pkgs.git
            nix-darwin.packages.${system}.default
          ];
          text = ''
            set -euo pipefail

            repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
            ${if useSudo then "exec sudo darwin-rebuild ${command} --flake \"$repo_root#remilis\" \"$@\"" else "exec darwin-rebuild ${command} --flake \"$repo_root#remilis\" \"$@\""}
          '';
        };
    in
    {
      packages.${system} = {
        build = mkDarwinCommand { command = "build"; };
        switch = mkDarwinCommand {
          command = "switch";
          useSudo = true;
        };
      };

      apps.${system} = {
        build = {
          type = "app";
          program = "${self.packages.${system}.build}/bin/darwin-build";
        };
        switch = {
          type = "app";
          program = "${self.packages.${system}.switch}/bin/darwin-switch";
        };
      };

      darwinConfigurations."remilis" = nix-darwin.lib.darwinSystem {
        modules = [
          ./darwin/configuration.nix
          home-manager.darwinModules.home-manager
          {
            users.users."toqoz".home = "/Users/toqoz";
            # android-nixpkgs' hmModule references `pkgs.androidSdk`, which is
            # supplied by its overlay. Because `home-manager.useGlobalPkgs` is
            # true, the overlay must live at the nix-darwin `nixpkgs` level.
            nixpkgs.overlays = [ android-nixpkgs.overlays.default ];
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [
              agent-skills.homeManagerModules.default
              android-nixpkgs.hmModule
            ];
            home-manager.extraSpecialArgs = {
              inherit llm-agents;
              inherit anthropic-skills;
              inherit vercel-agent-browser;
              inherit sence;
            };
            home-manager.users."toqoz" = ./home/home.nix;
          }
        ];
      };
    };
}
