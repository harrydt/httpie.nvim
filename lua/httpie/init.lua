local M = {}

function M.setup(opts)
  local cfg = require("httpie.config")
  cfg.setup(opts)

  -- filetype
  vim.filetype.add({ extension = { http = "http" } })

  -- user commands
  local cmd = vim.api.nvim_create_user_command

  cmd("HttpieRun", function()
    require("httpie.request").run_at_cursor()
  end, { desc = "Run HTTPie request at cursor" })

  cmd("HttpieOpen", function()
    require("httpie.storage").pick()
  end, { desc = "Open an HTTPie request collection" })

  cmd("HttpieNew", function(a)
    local name = a.args ~= "" and a.args or nil
    if name then
      require("httpie.storage").new(name)
    else
      vim.ui.input({ prompt = "Collection name: " }, function(n)
        if n and n ~= "" then require("httpie.storage").new(n) end
      end)
    end
  end, { nargs = "?", desc = "Create a new HTTPie request collection" })

  cmd("HttpieSave", function()
    require("httpie.storage").save_at_cursor()
  end, { desc = "Save request at cursor to a collection" })

  cmd("HttpieClose", function()
    require("httpie.storage").close_current()
  end, { desc = "Close the current .http buffer and return to the previous buffer" })

  cmd("HttpieImport", function(a)
    require("httpie.import").replace_range(a.line1, a.line2)
  end, { range = true, desc = "Convert a pasted httpie command into .http format" })

  cmd("HttpieExport", function()
    require("httpie.import").export_at_cursor()
  end, { desc = "Export the request at cursor as an httpie CLI command (copied to clipboard)" })
end

return M
