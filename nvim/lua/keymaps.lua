vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<CR>")

vim.keymap.set("n", "<leader>yd", function()
	local bufnr = 0
	local line = vim.api.nvim_win_get_cursor(0)[1] - 1
	local diags = vim.diagnostic.get(bufnr, { lnum = line })

	if vim.tbl_isempty(diags) then
		vim.notify("No diagnostics on current line", vim.log.levels.INFO)
		return
	end

	local severity_name = {
		[vim.diagnostic.severity.ERROR] = "ERROR",
		[vim.diagnostic.severity.WARN] = "WARN",
		[vim.diagnostic.severity.INFO] = "INFO",
		[vim.diagnostic.severity.HINT] = "HINT",
	}

	local lines = {}
	for _, d in ipairs(diags) do
		local source = d.source and (" [" .. d.source .. "]") or ""
		table.insert(lines, ("%s%s: %s"):format(severity_name[d.severity] or "UNKNOWN", source, d.message))
	end

	local text = table.concat(lines, "\n")
	vim.fn.setreg("+", text)
	vim.fn.setreg('"', text)

	vim.notify("Copied diagnostics to clipboard", vim.log.levels.INFO)
end, { desc = "Yank diagnostics on current line" })

-- Emacs-like keybinds in command-line mode
vim.keymap.set("c", "<C-A>", "<Home>")
vim.keymap.set("c", "<C-E>", "<End>")
vim.keymap.set("c", "<C-F>", "<Right>")
vim.keymap.set("c", "<C-B>", "<Left>")
vim.keymap.set("c", "<C-P>", "<Up>")
vim.keymap.set("c", "<C-N>", "<Down>")
vim.keymap.set("c", "<C-K>", [[<C-\>e getcmdpos() == 1 ? '' : getcmdline()[:getcmdpos()-2]<CR>]])
