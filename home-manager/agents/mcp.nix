{ ... }:
{
  programs.mcp = {
    enable = true;
    servers = {
      # Since the Remote MCP Server does not support multiple accounts, I will use the MCP Server from the Desktop app.
      Figma = {
        type = "http";
        url = "http://127.0.0.1:3845/mcp";
      };
    };
  };
}
