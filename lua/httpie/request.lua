local M = {}

local HTTP_METHODS = { GET = true, POST = true, PUT = true, PATCH = true, DELETE = true, HEAD = true, OPTIONS = true }

local SENSITIVE_HEADERS = {
  authorization = true,
  cookie = true,
  ["set-cookie"] = true,
  ["x-api-key"] = true,
  ["x-auth-token"] = true,
  ["proxy-authorization"] = true,
}

-- Parse a block of lines (one request) into a structured table
function M.parse_block(lines)
  local req = { name = nil, method = nil, url = nil, headers = {}, body_lines = {} }
  local state = "meta"

  for _, line in ipairs(lines) do
    if state == "meta" then
      local sep_name = line:match("^###%s*(.*)")
      if sep_name then
        req.name = vim.trim(sep_name) ~= "" and vim.trim(sep_name) or nil
      elseif not line:match("^#") and not line:match("^%s*$") then
        state = "first_line"
      end
    end

    if state == "first_line" then
      local method, url = line:match("^([A-Z]+)%s+(%S+)")
      if method and HTTP_METHODS[method] then
        req.method = method
        req.url = url
        state = "headers"
      end
    elseif state == "headers" then
      if line:match("^%s*$") then
        state = "body"
      elseif line:match("^#") then
        -- comment inside request block, skip
      else
        local key, value = line:match("^([^:]+):%s*(.+)")
        if key then
          table.insert(req.headers, { key = vim.trim(key), value = vim.trim(value) })
        end
      end
    elseif state == "body" then
      table.insert(req.body_lines, line)
    end
  end

  -- trim trailing blank lines from body
  while #req.body_lines > 0 and req.body_lines[#req.body_lines]:match("^%s*$") do
    table.remove(req.body_lines)
  end

  return req
end

-- Locate the request block around the cursor and parse it
function M.at_cursor(bufnr)
  bufnr = bufnr or 0
  local all = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cur = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-indexed

  local block_start = 0
  for i = cur, 0, -1 do
    if all[i + 1] and all[i + 1]:match("^###") then
      block_start = i
      break
    end
  end

  local block_end = #all
  for i = cur + 1, #all - 1 do
    if all[i + 1] and all[i + 1]:match("^###") then
      block_end = i
      break
    end
  end

  local block = {}
  for i = block_start, block_end - 1 do
    table.insert(block, all[i + 1])
  end

  return M.parse_block(block)
end

-- Build the shell command parts for a parsed request. When `mask` is set,
-- sensitive header values are replaced with "***" - used for the command
-- echoed into the output buffer, never for the command actually executed.
local function build_cmd(req, binary, has_body, mask)
  local env = require("httpie.env")

  local parts = { binary, "--pretty=format" }
  if not has_body then
    -- avoid blocking on nvim's job stdin pipe, which is never closed
    table.insert(parts, "--ignore-stdin")
  end

  table.insert(parts, req.method)
  table.insert(parts, vim.fn.shellescape(env.substitute_vars(req.url)))

  for _, h in ipairs(req.headers) do
    local val = (mask and SENSITIVE_HEADERS[h.key:lower()]) and "***" or env.substitute_vars(h.value)
    table.insert(parts, vim.fn.shellescape(h.key .. ":" .. val))
  end

  return parts
end

-- Execute a parsed request, rendering output to the UI
function M.execute(req)
  if not req.method then
    vim.notify("httpie.nvim: no request found at cursor", vim.log.levels.WARN)
    return
  end

  local cfg = require("httpie.config").opts
  local env = require("httpie.env")
  local ui = require("httpie.ui")

  local body = #req.body_lines > 0 and table.concat(req.body_lines, "\n") or nil
  local parts = build_cmd(req, cfg.binary, body ~= nil)
  local display_parts = build_cmd(req, cfg.binary, body ~= nil, true)

  -- pipe body via stdin when present
  local cmd_str, display_cmd_str
  if body then
    body = env.substitute_vars(body)
    local piped_body = "echo " .. vim.fn.shellescape(body) .. " | "
    cmd_str = piped_body .. table.concat(parts, " ")
    display_cmd_str = piped_body .. table.concat(display_parts, " ")
  else
    cmd_str = table.concat(parts, " ")
    display_cmd_str = table.concat(display_parts, " ")
  end

  local bufnr = ui.open()
  local label = req.name or (req.method .. " " .. req.url)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
    "# " .. label,
    "# $ " .. display_cmd_str,
    "# Running...",
    "",
  })

  local stdout_acc, stderr_acc = {}, {}

  vim.fn.jobstart({ "/bin/sh", "-c", cmd_str }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then vim.list_extend(stdout_acc, data) end
    end,
    on_stderr = function(_, data)
      if data then vim.list_extend(stderr_acc, data) end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        local out = {
          "# " .. label,
          "# $ " .. display_cmd_str,
          "",
        }
        if code ~= 0 and #stderr_acc > 0 then
          table.insert(out, "## Error (exit " .. code .. ")")
          table.insert(out, "")
          vim.list_extend(out, stderr_acc)
        else
          vim.list_extend(out, stdout_acc)
          if #stderr_acc > 0 then
            table.insert(out, "")
            table.insert(out, "## stderr")
            vim.list_extend(out, stderr_acc)
          end
        end
        ui.write(out)
      end)
    end,
  })
end

function M.run_at_cursor()
  M.execute(M.at_cursor())
end

return M
