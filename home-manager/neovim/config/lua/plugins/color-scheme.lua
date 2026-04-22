return {
	"catppuccin/nvim",
	name = "catppuccin",
	priority = 1000,
	config = function()
		require("catppuccin").setup({
			flavour = "mocha",
			transparent_background = true,
			custom_highlights = function(colors)
				return {
					StatusLineNC = {
						fg = colors.overlay0,
						bg = colors.surface0,
					},
					-- active
					StatusLine = {
						fg = colors.text,
						bg = colors.surface1,
					},
				}
			end,
		})
		vim.cmd.colorscheme("catppuccin")
	end,
}
