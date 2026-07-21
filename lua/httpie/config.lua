local M = {}

M.opts = {}

M.defaults = {
  storage_dir = vim.fn.stdpath("data") .. "/httpie-nvim",
  env_file = "httpie-env.json",
  binary = "http",
  output = {
    split = "vertical", -- "vertical" | "horizontal" | "float"
    size = 80,
  },
}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
