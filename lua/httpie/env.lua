local M = {}

-- Parse "@name = value" declarations out of buffer lines into a lookup table.
---@param lines string[]
---@return table<string, string>
function M.parse_file_vars(lines)
  local vars = {}
  for _, line in ipairs(lines) do
    local name, value = line:match("^@([%w_]+)%s*=%s*(.-)%s*$")
    if name then
      vars[name] = value
    end
  end
  return vars
end

-- Substitute {{VAR}} placeholders. OS environment variables take precedence
-- over in-file @var declarations, matching JetBrains HTTP Client semantics.
---@param str string
---@param file_vars table<string, string>|nil
---@return string
function M.substitute_vars(str, file_vars)
  return (str:gsub("{{([%w_]+)}}", function(key)
    if vim.env[key] ~= nil then
      return vim.env[key]
    end
    if file_vars and file_vars[key] ~= nil then
      return file_vars[key]
    end
    return "{{" .. key .. "}}"
  end))
end

return M
