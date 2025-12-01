--- Harpoon sidebar buffer implementation.
---
--- Renders the current Harpoon list in a small buffer and keeps it in sync
--- when items are added or removed.

local M = {}

local harpoon
local list
local orig_add
local orig_remove_at

local buf -- sidebar buffer handle

-- Configuration local to this module.
local config = {
    max_height = 20,
    min_height = 1,
}

-- Find the window currently displaying the sidebar buffer.
local function find_sidebar_win()
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end

    for _, w in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(w)
        if b == buf then
            return w
        end
    end
    return nil
end

-- Resize the sidebar window to match number of Harpoon items.
local function resize_sidebar()
    local win = find_sidebar_win()
    if not win then
        return
    end

    if not list then
        return
    end

    local count = #list.items
    local height = math.max(config.min_height, math.min(config.max_height, count))

    if height > 0 then
        pcall(vim.api.nvim_win_set_height, win, height)
    end
end

-- Ensure we have harpoon and a list, and instrument the list so that
-- updates trigger sidebar rerender/resize.
local function ensure_list()
    if list and harpoon then
        return true
    end

    local ok, h = pcall(require, "harpoon")
    if not ok then
        vim.notify(
            "[harpoon-sidebar] harpoon not found. Make sure ThePrimeagen/harpoon is installed and configured.",
            vim.log.levels.WARN
        )
        return false
    end

    harpoon = h

    -- harpoon:setup() must have been called by the user already.
    list = harpoon:list()
    if not list then
        vim.notify("[harpoon-sidebar] harpoon:list() returned nil. Did you call harpoon:setup()?", vim.log.levels.WARN)
        return false
    end

    -- Instrument the list to auto-refresh the sidebar when items change.
    orig_add = list.add
    orig_remove_at = list.remove_at

    function list:add(...)
        orig_add(self, ...)
        if buf and vim.api.nvim_buf_is_valid(buf) then
            M.render()
            resize_sidebar()
        end
    end

    function list:remove_at(...)
        orig_remove_at(self, ...)
        if buf and vim.api.nvim_buf_is_valid(buf) then
            M.render()
            resize_sidebar()
        end
    end

    return true
end

-- Render the sidebar buffer.
function M.render()
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
        return
    end

    if not ensure_list() then
        return
    end

    local lines = {}

    for i, item in ipairs(list.items) do
        local name = item.value
        if type(name) == "string" then
            name = vim.fn.fnamemodify(name, ":t")
        else
            name = tostring(name)
        end
        table.insert(lines, string.format("%d  %s", i, name))
    end

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

-- Create the sidebar buffer if needed.
local function ensure_buf()
    if buf and vim.api.nvim_buf_is_valid(buf) then
        return buf
    end

    buf = vim.api.nvim_create_buf(false, false)

    -- Mark this buffer as the Harpoon sidebar so we can
    -- recognize its windows from other modules.
    vim.b[buf].harpoon_sidebar = true

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].buflisted = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false

    -- Use 'qf' filetype so Neo-tree will not use this window
    -- for opening files, because its default
    -- `open_files_do_not_replace_types` includes "qf".
    vim.bo[buf].filetype = "qf"

    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true

    -- Manual refresh under <leader>hr (buffer-local)
    vim.keymap.set("n", "<leader>hr", function()
        M.render()
        resize_sidebar()
    end, { buffer = buf, desc = "Refresh Harpoon sidebar", silent = true })

    return buf
end

-- Open sidebar buffer in the current window.
function M.open()
    if not ensure_list() then
        return
    end

    local b = ensure_buf()

    vim.api.nvim_win_set_buf(0, b)
    M.render()
    resize_sidebar()
end

-- Auto-refresh when entering the sidebar window.
vim.api.nvim_create_autocmd("BufEnter", {
    callback = function(args)
        if buf and vim.api.nvim_buf_is_valid(buf) and args.buf == buf then
            if ensure_list() then
                M.render()
                resize_sidebar()
            end
        end
    end,
})

return M
