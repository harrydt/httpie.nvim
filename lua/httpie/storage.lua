local M = {}

local TEMPLATE = [[
### Example GET
# Replace with your request details
GET https://httpbin.org/get
Accept: application/json


### Example POST
POST https://httpbin.org/post
Content-Type: application/json

{"key": "value"}
]]

local function storage_dir()
  local cfg = require("httpie.config").opts
  local dir = cfg.storage_dir
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

function M.list()
  local dir = storage_dir()
  local paths = vim.fn.glob(dir .. "/*.http", false, true)
  return vim.tbl_map(function(p)
    return { name = vim.fn.fnamemodify(p, ":t:r"), path = p }
  end, paths)
end

-- Edit path in the current window, remembering the buffer we came from so
-- :HttpieClose can return to it.
local function open_and_track(path)
  local prev_buf = vim.api.nvim_get_current_buf()
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  vim.b.httpie_prev_buf = prev_buf
end

function M.open(name)
  local dir = storage_dir()
  open_and_track(dir .. "/" .. name .. ".http")
end

function M.new(name)
  local dir = storage_dir()
  local path = dir .. "/" .. name .. ".http"
  if vim.fn.filereadable(path) == 1 then
    vim.notify("httpie.nvim: collection '" .. name .. "' already exists, opening it")
  else
    vim.fn.writefile(vim.split(TEMPLATE, "\n"), path)
  end
  open_and_track(path)
end

-- Close the current .http buffer and return to whichever buffer was active
-- before it was opened via :HttpieOpen / :HttpieNew.
function M.close_current()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "http" then
    vim.notify("httpie.nvim: not an .http buffer", vim.log.levels.WARN)
    return
  end
  if vim.bo[bufnr].modified then
    vim.notify("httpie.nvim: unsaved changes - save first (:w) or force with :bd!", vim.log.levels.WARN)
    return
  end

  local prev_buf = vim.b[bufnr].httpie_prev_buf
  if prev_buf and vim.api.nvim_buf_is_valid(prev_buf) then
    vim.api.nvim_win_set_buf(0, prev_buf)
  end

  vim.api.nvim_buf_delete(bufnr, { force = false })
end

-- Pick a collection interactively, or prompt to create one
function M.pick()
  local collections = M.list()
  local items = vim.tbl_map(function(c) return c.name end, collections)
  table.insert(items, "+ New collection…")

  vim.ui.select(items, { prompt = "HTTPie collections: " }, function(choice)
    if not choice then return end
    if choice == "+ New collection…" then
      vim.ui.input({ prompt = "Collection name: " }, function(name)
        if name and name ~= "" then M.new(name) end
      end)
    else
      M.open(choice)
    end
  end)
end

-- Append the request block around the cursor to a chosen collection
function M.save_at_cursor()
  local request = require("httpie.request")
  local bufnr = vim.api.nvim_get_current_buf()
  local all = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cur = vim.api.nvim_win_get_cursor(0)[1] - 1

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

  local req = request.at_cursor(bufnr)
  if not req.method then
    vim.notify("httpie.nvim: no request at cursor", vim.log.levels.WARN)
    return
  end

  local block = {}
  for i = block_start, block_end - 1 do
    table.insert(block, all[i + 1])
  end

  local collections = M.list()
  local items = vim.tbl_map(function(c) return c.name end, collections)
  table.insert(items, "+ New collection…")

  vim.ui.select(items, { prompt = "Save to collection: " }, function(choice)
    if not choice then return end

    local function append_to(name)
      local dir = storage_dir()
      local path = dir .. "/" .. name .. ".http"
      local existing = vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
      if #existing > 0 then table.insert(existing, "") end
      vim.list_extend(existing, block)
      vim.fn.writefile(existing, path)
      vim.notify("httpie.nvim: saved to '" .. name .. "'")
    end

    if choice == "+ New collection…" then
      vim.ui.input({ prompt = "Collection name: " }, function(name)
        if name and name ~= "" then append_to(name) end
      end)
    else
      append_to(choice)
    end
  end)
end

return M
