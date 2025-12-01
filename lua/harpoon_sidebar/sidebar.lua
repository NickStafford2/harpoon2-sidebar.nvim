-- lua/personal/harpoon_buffer.lua
local M = {}

local harpoon = require("harpoon")
local buf

-- Find the window currently displaying the sidebar buffer
local function find_sidebar_win()
	for _, w in ipairs(vim.api.nvim_list_wins()) do
		local b = vim.api.nvim_win_get_buf(w)
		if b == buf then
			return w
		end
	end
	return nil
end

-- Resize the sidebar to match number of Harpoon items
local function resize_sidebar()
	local win = find_sidebar_win()
	if not win then
		return
	end

	local count = #harpoon:list().items
	local height = math.max(1, math.min(count, 20))

	vim.api.nvim_win_set_height(win, height)
end

-- Render the sidebar buffer
local function render()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local list = harpoon:list()
	local lines = {}

	for i, item in ipairs(list.items) do
		local name = vim.fn.fnamemodify(item.value, ":t")
		table.insert(lines, string.format("%d  %s", i, name))
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
end

M.render = render

-- Open sidebar buffer (called by neotree_harpoon.lua)
function M.open()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		buf = vim.api.nvim_create_buf(false, false)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].buflisted = false -- sidebar should not be treated as a file buffer
		vim.bo[buf].bufhidden = "hide"
		vim.bo[buf].swapfile = false
		vim.bo[buf].filetype = "harpoonlist"
		vim.bo[buf].modifiable = false
		vim.bo[buf].readonly = true

		-- Manual refresh under <leader>hr
		vim.keymap.set("n", "<leader>hr", function()
			render()
		end, { buffer = buf, desc = "Refresh Harpoon sidebar", silent = true })
	end

	vim.api.nvim_win_set_buf(0, buf)
	render()
	resize_sidebar()
end

-- Ensure the sidebar updates when Harpoon list changes
local list = harpoon:list()

local orig_add = list.add
local orig_remove_at = list.remove_at

function list:add(...)
	orig_add(self, ...)
	if buf and vim.api.nvim_buf_is_valid(buf) then
		render()
		resize_sidebar()
	end
end

function list:remove_at(...)
	orig_remove_at(self, ...)
	if buf and vim.api.nvim_buf_is_valid(buf) then
		render()
		resize_sidebar()
	end
end

-- Auto-refresh when entering the sidebar window
vim.api.nvim_create_autocmd("BufEnter", {
	callback = function(args)
		if buf and vim.api.nvim_buf_is_valid(buf) and args.buf == buf then
			render()
			resize_sidebar()
		end
	end,
})

return M
