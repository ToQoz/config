vim.loader.enable()

require("options")
require("keymaps")
require("plugin-manager")

-- mkdir -p
vim.api.nvim_create_autocmd("BufWritePre", {
	callback = function(event)
		local dir = vim.fn.fnamemodify(event.match, ":p:h")
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, "p")
		end
	end,
})
