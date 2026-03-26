return {
	"nvim-telescope/telescope.nvim",
	version = "*",
	dependencies = {
		"nvim-lua/plenary.nvim",
		-- optional but recommended
		{
			"nvim-telescope/telescope-fzy-native.nvim",
			dir = vim.env.TELESCOPE_FZY_NATIVE,
		},
	},
	keys = {
		{ mode = "n", "<D-p>", "<cmd>Telescope find_files<CR>", {} },
		{ mode = "n", "<Leader>ff", "<cmd>Telescope find_files<CR>", {} },
		{ mode = "n", "<Leader>fg", "<cmd>Telescope live_grep<CR>", {} },
		{ mode = "n", "<Leader>fb", "<cmd>Telescope buffers<CR>", {} },
		{ mode = "n", "<Leader>fh", "<cmd>Telescope help_tags<CR>", {} },
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.setup({
			defaults = {
				mappings = {
					i = {
						["<esc>"] = actions.close,
					},
				},
			},
		})
		telescope.load_extension("fzy_native")
	end,
}
