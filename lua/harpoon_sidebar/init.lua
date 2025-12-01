--- All function(s) that can be called externally by other Lua modules.
---
--- If a function's signature here changes in some incompatible way, this
--- package must get a new **major** version.
---

local M = {}

function M.setup(opts)
    M.opts = opts or {}

    -- Load sidebar functionality
    require("harpoon_sidebar.sidebar")

    -- Load neotree integration (optional)
    require("harpoon_sidebar.neotree")
end

-- Allow direct calls like require("harpoon_sidebar").open()
M.open = function()
    require("harpoon_sidebar.sidebar").open()
end

return M
