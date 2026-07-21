local M = {}

-- httpie's own auto-added headers when none of these are explicitly set by the user
local AUTO_HEADERS = {
  ["accept-encoding"] = true,
  ["connection"] = true,
  ["content-length"] = true,
  ["user-agent"] = true,
  ["host"] = true,
  ["accept"] = true,
}

-- Split a command string into shell-like words, respecting quotes and backslash escapes.
local function shell_split(str)
  local tokens = {}
  local i, n = 1, #str
  while i <= n do
    while i <= n and str:sub(i, i):match("%s") do i = i + 1 end
    if i > n then break end
    local buf = {}
    while i <= n and not str:sub(i, i):match("%s") do
      local c = str:sub(i, i)
      if c == "'" then
        local j = str:find("'", i + 1, true) or n
        table.insert(buf, str:sub(i + 1, j - 1))
        i = j + 1
      elseif c == '"' then
        local j = i + 1
        local inner = {}
        while j <= n and str:sub(j, j) ~= '"' do
          if str:sub(j, j) == "\\" and j < n then
            table.insert(inner, str:sub(j + 1, j + 1))
            j = j + 2
          else
            table.insert(inner, str:sub(j, j))
            j = j + 1
          end
        end
        table.insert(buf, table.concat(inner))
        i = j + 1
      elseif c == "\\" and i < n then
        table.insert(buf, str:sub(i + 1, i + 1))
        i = i + 2
      else
        table.insert(buf, c)
        i = i + 1
      end
    end
    table.insert(tokens, table.concat(buf))
  end
  return tokens
end

-- httpie item syntax that reads a local file (key@file, key=@file, key:=@file) -
-- httpie itself would try to open that file and fail if it doesn't exist here.
local function is_file_item(token)
  if token:match("^[^:=]+:=@") or token:match("^[^:=]+=@") then return true end
  if not token:find("[:=]") and token:find("@") then return true end
  return false
end

-- Convert shell-style $VAR / ${VAR} references (left over from a pasted
-- command) into httpie.nvim's {{VAR}} template syntax.
local function shell_vars_to_mustache(str)
  return (str:gsub("%$%{([%w_]+)%}", "{{%1}}"):gsub("%$([%w_]+)", "{{%1}}"))
end

-- Convert httpie.nvim's {{VAR}} template syntax back to a shell-style $VAR
-- reference, so exported commands never bake in a resolved secret value.
local function mustache_to_shell_vars(str)
  return (str:gsub("{{([%w_]+)}}", "$%1"))
end

-- Does this string need shell-quoting to survive as a single argument?
local function needs_quote(s)
  return s:find("[%s$\"'&|;<>%(%)%?#%*]") ~= nil
end

-- Double-quote a string for shell use, preserving $VAR expansion.
local function dquote(s)
  return '"' .. s:gsub('[\\"`]', "\\%0") .. '"'
end

local function shell_arg(s)
  return needs_quote(s) and dquote(s) or s
end

-- If the item is a header (key:value, not key:=value), return its lowercased key.
local function header_key(token)
  local key, rest = token:match("^([^:=]+)(.*)$")
  if key and rest:sub(1, 1) == ":" and rest:sub(1, 2) ~= ":=" then
    return key:lower()
  end
  return nil
end

-- Parse an httpie CLI invocation string into a request table, or nil + error.
-- Delegates the actual item-syntax parsing (auth, JSON/form bodies, query
-- params) to the real `http` binary via --offline, which builds but doesn't
-- send the request.
function M.parse(cmd_str)
  cmd_str = cmd_str:gsub("^%s*%$%s+", "")
  local tokens = shell_split(cmd_str)
  if #tokens == 0 then return nil, "empty command" end

  if tokens[1]:match("/?https?$") then
    table.remove(tokens, 1)
  end

  local kept, unsupported = {}, {}
  local explicit_headers = {}
  for _, t in ipairs(tokens) do
    if is_file_item(t) then
      table.insert(unsupported, t)
    else
      table.insert(kept, t)
      local key = header_key(t)
      if key then explicit_headers[key] = true end
    end
  end

  if #kept == 0 then return nil, "nothing left to convert" end

  -- Pull scheme + host straight from the original text so a placeholder like
  -- $HOST keeps its exact casing - httpie's own URL parser lowercases hosts.
  local scheme, orig_host = "http", nil
  for _, t in ipairs(tokens) do
    local s, h = t:match("^(https?)://([^/%s]+)")
    if s then
      scheme, orig_host = s, h
      break
    end
  end

  local cfg = require("httpie.config").opts
  local argv = { cfg.binary, "--ignore-stdin", "--offline", "--pretty=none", "--print=HB" }
  vim.list_extend(argv, kept)
  local parts = {}
  for _, a in ipairs(argv) do table.insert(parts, vim.fn.shellescape(a)) end
  local output = vim.fn.system(table.concat(parts, " ") .. " 2>&1")
  if vim.v.shell_error ~= 0 then
    return nil, "httpie: " .. vim.trim(output)
  end

  local lines = vim.split(output:gsub("\r\n", "\n"), "\n", { plain = true })
  local method, path = lines[1]:match("^(%u+)%s+(%S+)%s+HTTP")
  if not method then return nil, "could not parse httpie output" end

  local headers, host = {}, nil
  local i = 2
  while lines[i] and lines[i] ~= "" do
    local key, value = lines[i]:match("^([^:]+):%s*(.*)$")
    if key then
      if key:lower() == "host" then host = value end
      if not AUTO_HEADERS[key:lower()] or explicit_headers[key:lower()] then
        table.insert(headers, { key = key, value = shell_vars_to_mustache(value) })
      end
    end
    i = i + 1
  end
  if not host then return nil, "no Host header in httpie output" end
  host = orig_host or host

  local body_lines = {}
  for j = i + 1, #lines do table.insert(body_lines, lines[j]) end
  while #body_lines > 0 and body_lines[#body_lines] == "" do table.remove(body_lines) end
  local body = #body_lines > 0 and shell_vars_to_mustache(table.concat(body_lines, "\n")) or nil

  return {
    method = method,
    url = shell_vars_to_mustache(scheme .. "://" .. host .. path),
    headers = headers,
    body = body,
    unsupported = unsupported,
  }
end

-- Render a parsed request into .http block lines.
function M.render(req)
  local lines = { "###", req.method .. " " .. req.url }
  for _, h in ipairs(req.headers) do
    table.insert(lines, h.key .. ": " .. h.value)
  end
  table.insert(lines, "")
  if req.body then
    table.insert(lines, req.body)
  end
  if #req.unsupported > 0 then
    table.insert(lines, "")
    table.insert(lines, "# NOTE: could not convert: " .. table.concat(req.unsupported, " "))
  end
  return lines
end

-- Build an httpie CLI command string from a parsed .http request (as
-- returned by httpie.request.at_cursor). {{VAR}} placeholders become $VAR so
-- the command stays copy-pasteable without ever containing a resolved secret.
function M.to_cli(req)
  local parts = { "http", req.method, shell_arg(mustache_to_shell_vars(req.url)) }
  for _, h in ipairs(req.headers) do
    table.insert(parts, h.key .. ":" .. shell_arg(mustache_to_shell_vars(h.value)))
  end
  if req.body_lines and #req.body_lines > 0 then
    local body = mustache_to_shell_vars(table.concat(req.body_lines, "\n"))
    table.insert(parts, "--raw=" .. shell_arg(body))
  end
  return table.concat(parts, " ")
end

-- Export the request at cursor as an httpie CLI command, copied to the
-- system clipboard.
function M.export_at_cursor()
  local req = require("httpie.request").at_cursor()
  if not req.method then
    vim.notify("httpie.nvim: no request found at cursor", vim.log.levels.WARN)
    return
  end

  local cmd_str = M.to_cli(req)
  vim.fn.setreg("+", cmd_str)
  vim.notify("httpie.nvim: copied to clipboard:\n" .. cmd_str)
end

-- Replace a range of lines (e.g. a visual selection) containing a pasted
-- httpie command with the equivalent .http block.
function M.replace_range(line1, line2)
  local bufnr = vim.api.nvim_get_current_buf()
  local raw_lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)

  local joined = {}
  for _, l in ipairs(raw_lines) do
    table.insert(joined, (l:gsub("%s+$", ""):gsub("\\$", "")))
  end
  local cmd_str = table.concat(joined, " ")

  local req, err = M.parse(cmd_str)
  if not req then
    vim.notify("httpie.nvim: " .. (err or "could not parse httpie command"), vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, line1 - 1, line2, false, M.render(req))
end

return M
