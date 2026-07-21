local M = {}

local _active_env = nil

local function get_env_file_path()
  local cfg = require("httpie.config").opts
  return vim.fn.getcwd() .. "/" .. cfg.env_file
end

function M.load_envs()
  local path = get_env_file_path()
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local content = table.concat(vim.fn.readfile(path), "\n")
  local ok, parsed = pcall(vim.fn.json_decode, content)
  if not ok or type(parsed) ~= "table" then
    vim.notify("httpie.nvim: failed to parse " .. path, vim.log.levels.ERROR)
    return {}
  end
  return parsed
end

function M.get_active_name()
  return _active_env
end

-- Resolve a var: prefer the active environment's own value, falling back to
-- an OS environment variable of the same name.
local function resolve_var(vars, key)
  if vars[key] ~= nil then return vars[key] end
  return vim.env[key]
end

function M.get_active_vars()
  if not _active_env then return {} end
  local envs = M.load_envs()
  local vars = envs[_active_env] or {}

  -- allow values in httpie-env.json to reference OS env vars, e.g.
  -- "TOKEN": "{{OS_TOKEN}}"
  local resolved = {}
  for k, v in pairs(vars) do
    if type(v) == "string" then
      resolved[k] = (v:gsub("{{([%w_]+)}}", function(inner)
        return resolve_var(vars, inner) or ("{{" .. inner .. "}}")
      end))
    else
      resolved[k] = v
    end
  end
  return resolved
end

function M.substitute_vars(str)
  local vars = M.get_active_vars()
  return (str:gsub("{{([%w_]+)}}", function(key)
    return resolve_var(vars, key) or ("{{" .. key .. "}}")
  end))
end

function M.select()
  local envs = M.load_envs()
  local names = vim.tbl_keys(envs)
  if #names == 0 then
    vim.notify("httpie.nvim: no environments in " .. get_env_file_path(), vim.log.levels.WARN)
    return
  end
  table.sort(names)
  vim.ui.select(names, { prompt = "Select environment: " }, function(choice)
    if choice then
      _active_env = choice
      vim.notify("httpie.nvim: environment → " .. choice)
    end
  end)
end

function M.edit()
  local path = get_env_file_path()
  if vim.fn.filereadable(path) == 0 then
    local template = vim.fn.json_encode({
      dev = { BASE_URL = "https://dev.example.com", TOKEN = "dev-token" },
      prod = { BASE_URL = "https://api.example.com", TOKEN = "prod-token" },
    })
    vim.fn.writefile(vim.split(template, "\n"), path)
  end
  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

function M.show()
  local name = _active_env
  if not name then
    vim.notify("httpie.nvim: no active environment")
    return
  end
  local vars = M.get_active_vars()
  local lines = { "Environment: " .. name }
  for k, v in pairs(vars) do
    table.insert(lines, string.format("  %s = %s", k, v))
  end
  vim.notify(table.concat(lines, "\n"))
end

return M
