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
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-darwin,
      llm-agents,
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
            home-manager.extraSpecialArgs = {
              inherit llm-agents;
            };
            home-manager.users."toqoz" = ./home-manager/home.nix;
          }
        ];
      };
    };
}
