local M = {}

local state = { bufnr = nil, winid = nil }

local function open_float(bufnr)
  local width = math.max(80, math.floor(vim.o.columns * 0.75))
  local height = math.max(20, math.floor(vim.o.lines * 0.75))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  return vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    title = " HTTPie Output ",
    title_pos = "center",
  })
end

function M.open()
  local cfg = require("httpie.config").opts.output
  local split = cfg.split or "vertical"
  local size = cfg.size or 80

  -- Reuse buffer if valid
  if not (state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)) then
    state.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(state.bufnr, "HTTPie Output")
    for opt, val in pairs({ buftype = "nofile", swapfile = false, bufhidden = "hide" }) do
      vim.api.nvim_buf_set_option(state.bufnr, opt, val)
    end
  end

  -- Reuse or open window
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_set_current_win(state.winid)
  else
    if split == "float" then
      state.winid = open_float(state.bufnr)
    else
      local cmd = split == "horizontal" and (size .. "split") or (size .. "vsplit")
      vim.cmd(cmd)
      vim.api.nvim_win_set_buf(0, state.bufnr)
      state.winid = vim.api.nvim_get_current_win()
    end
  end

  vim.api.nvim_buf_set_option(state.bufnr, "modifiable", true)
  return state.bufnr
end

function M.close()
  if state.winid and vim.api.nvim_win_is_valid(state.winid) then
    vim.api.nvim_win_close(state.winid, true)
    state.winid = nil
  end
end

function M.write(lines)
  if not (state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr)) then return end
  vim.api.nvim_buf_set_option(state.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.bufnr, "modifiable", false)
  -- apply syntax so JSON and headers are readable
  vim.api.nvim_buf_set_option(state.bufnr, "filetype", "httpie_output")
end

return M
