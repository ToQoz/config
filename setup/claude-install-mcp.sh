#!/bin/sh

claude mcp add Figma \
  --scope user \
  --transport sse \
  "http://127.0.0.1:3845/sse"
  
claude mcp add o3 --scope user \
	-e OPENAI_API_KEY="$(op read 'op://Private/openai-o3-search-mcp/credential')" \
	-e SEARCH_CONTEXT_SIZE=medium \
	-e REASONING_EFFORT=medium \
	-- dun o3-search-mcp
