local M = {}

---@class httpie.OutputConfig
---@field split "vertical"|"horizontal"|"float"
---@field size integer

---@class httpie.Config
---@field storage_dir string
---@field binary string
---@field output httpie.OutputConfig

---@type httpie.Config
M.opts = {}

---@type httpie.Config
M.defaults = {
  storage_dir = vim.fn.stdpath("data") .. "/httpie-nvim",
  binary = "http",
  output = {
    split = "vertical", -- "vertical" | "horizontal" | "float"
    size = 80,
  },
}

---@param opts httpie.Config|nil
function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
