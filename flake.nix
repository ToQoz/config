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
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-darwin,
      llm-agents,
      agent-skills,
      anthropic-skills,
      vercel-agent-browser,
      ...
    }:
    {
      darwinConfigurations."remilis" = nix-darwin.lib.darwinSystem {
        modules = [
          ./darwin/configuration.nix
          home-manager.darwinModules.home-manager
          {
            users.users."toqoz".home = "/Users/toqoz";
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.sharedModules = [
              agent-skills.homeManagerModules.default
            ];
            home-manager.extraSpecialArgs = {
              inherit llm-agents;
              inherit anthropic-skills;
              inherit vercel-agent-browser;
            };
            home-manager.users."toqoz" = ./home-manager/home.nix;
          }
        ];
      };
    };
}
