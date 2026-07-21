local M = {}

-- Substitute {{VAR}} placeholders from OS environment variables.
function M.substitute_vars(str)
  return (str:gsub("{{([%w_]+)}}", function(key)
    return vim.env[key] or ("{{" .. key .. "}}")
  end))
end

return M
