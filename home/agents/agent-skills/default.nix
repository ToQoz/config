{ vercel-agent-browser, ... }:
{
  imports = [ ./anthropic.nix ];

  programs.agent-skills = {
    enable = true;
    sources = {
      local = {
        path = ../skills;
        filter.maxDepth = 1;
      };
      vercel = {
        path = vercel-agent-browser;
        subdir = "skills";
      };
    };
    skills.enableAll = [
      "local"
      "vercel"
    ];
    targets.agents.enable = true;
    targets.claude.enable = true;
  };
}
