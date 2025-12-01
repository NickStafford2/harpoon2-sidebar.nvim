-- lua/personal/neotree_harpoon.lua
local M = {}

-- Simple toggle function you can map to <leader>e
function M.toggle()
	vim.cmd("Neotree toggle left")
	-- The BufWinEnter autocmd below will create the Harpoon pane
	-- whenever a neo-tree window actually opens.
end

-- When a neo-tree window closes, close any Harpoon panes too
vim.api.nvim_create_autocmd("WinClosed", {
	callback = function(event)
		local closed_win = tonumber(event.match)
		if not closed_win then
			return
		end

		-- Try to get the buffer that was in the closed window
		local ok, buf = pcall(vim.api.nvim_win_get_buf, closed_win)
		if not ok or not buf or not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		if vim.bo[buf].filetype ~= "neo-tree" then
			return -- not a neo-tree window, ignore
		end

		-- Neo-tree closed → close any harpoonlist windows in this tab
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			local b = vim.api.nvim_win_get_buf(win)
			if vim.bo[b].filetype == "harpoonlist" then
				vim.api.nvim_win_close(win, true)
			end
		end
	end,
})

-- Whenever we enter a neo-tree window, create the Harpoon pane under it
vim.api.nvim_create_autocmd("BufWinEnter", {
	callback = function(args)
		-- Only react to neo-tree buffers
		if vim.bo[args.buf].filetype ~= "neo-tree" then
			return
		end

		-- If there's already a Harpoon pane in this tab, do nothing
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			local b = vim.api.nvim_win_get_buf(win)
			if vim.bo[b].filetype == "harpoonlist" then
				return
			end
		end

		-- Save the Neo-tree window (active right now)
		local neotree_win = vim.api.nvim_get_current_win()

		-- Create the split BELOW Neo-tree
		vim.cmd("belowright split")
		vim.cmd("resize 15")

		-- Open Harpoon buffer in *this* new window
		require("personal.harpoon_buffer").open()

		-- 🚨 IMPORTANT: restore focus to Neo-tree window
		vim.api.nvim_set_current_win(neotree_win)
	end,
})

return M
