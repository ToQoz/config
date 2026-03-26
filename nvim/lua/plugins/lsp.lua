return {
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			vim.lsp.config(
				"*",
				(function()
					local opts = {}
					local blink = require("blink.cmp")
					local capabilities = blink.get_lsp_capabilities()
					opts.capabilities = capabilities
					return opts
				end)()
			)
			vim.lsp.enable({ "nixd", "lua_ls" })

			-- vim.lsp.config("nixd", {
			-- 	cmd = { "nixd" },
			-- 	filetypes = { "nix" },
			-- 	capabilities = capabilities,
			-- 	settings = {
			-- 		nixd = {
			-- 			nixpkgs = {
			-- 				expr = "import <nixpkgs> { }",
			-- 			},
			-- 		},
			-- 	},
			-- })

			vim.lsp.config("lua_ls", {
				settings = {
					Lua = {
						runtime = {
							version = "LuaJIT",
						},
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							checkThirdParty = false,
							library = vim.api.nvim_get_runtime_file("", true),
						},
					},
				},
			})
		end,
	},
}
