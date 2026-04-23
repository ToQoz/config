{ anthropic-skills, vercel-agent-browser, ... }:
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
    };
    targets.claude.enable = true;
  };
}
