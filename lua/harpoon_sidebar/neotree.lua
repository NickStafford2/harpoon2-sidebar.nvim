-- lua/harpoon_sidebar/neotree.lua
-- Safe + race-proof Neo-tree integration.

local M = {}

function M.toggle()
    vim.cmd("Neotree toggle left")
end

-------------------------------------------------------------
-- Utility: sidebar existence
-------------------------------------------------------------
local function sidebar_exists()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local b = vim.api.nvim_win_get_buf(win)
        if vim.b[b] and vim.b[b].harpoon_sidebar then
            return true
        end
    end
    return false
end

-------------------------------------------------------------
-- Return the *actual* window showing this buffer.
-- Uses win_findbuf instead of unreliable autocmd args.
-------------------------------------------------------------
local function get_neotree_window(buf)
    local wins = vim.fn.win_findbuf(buf)
    if #wins == 0 then
        return nil
    end

    -- Usually one win, but if multiple, prefer the leftmost column
    table.sort(wins, function(a, b)
        return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
    end)

    return wins[1]
end

-------------------------------------------------------------
-- Create sidebar only when a real Neo-tree window is created.
-------------------------------------------------------------
vim.api.nvim_create_autocmd("BufWinEnter", {
    callback = function(args)
        local buf = args.buf

        -- Not neo-tree
        if vim.bo[buf].filetype ~= "neo-tree" then
            return
        end

        -- Already have a sidebar → do nothing
        if sidebar_exists() then
            return
        end

        -- Find the *real* window where Neo-tree lives
        local neotree_win = get_neotree_window(buf)
        if not neotree_win then
            return -- Neo-tree not actually displayed yet
        end

        -- Load sidebar module
        local sidebar = require("harpoon_sidebar.sidebar")

        -- Split *from that window* and open sidebar below
        vim.api.nvim_win_call(neotree_win, function()
            vim.cmd("belowright split")
            vim.cmd("resize 15")
            sidebar.open()
        end)

        -- Restore cursor to Neo-tree window
        vim.api.nvim_set_current_win(neotree_win)
    end,
})

-------------------------------------------------------------
-- Remove sidebar when Neo-tree closes
-------------------------------------------------------------
vim.api.nvim_create_autocmd("WinClosed", {
    callback = function(event)
        local closed = tonumber(event.match)
        if not closed then
            return
        end

        local ok, buf = pcall(vim.api.nvim_win_get_buf, closed)
        if not ok or not vim.api.nvim_buf_is_valid(buf) then
            return
        end

        -- Only react when an actual neo-tree window closes
        if vim.bo[buf].filetype ~= "neo-tree" then
            return
        end

        -- Close sidebars in same tab
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            local b = vim.api.nvim_win_get_buf(win)
            if vim.b[b] and vim.b[b].harpoon_sidebar then
                pcall(vim.api.nvim_win_close, win, true)
            end
        end
    end,
})

return M
