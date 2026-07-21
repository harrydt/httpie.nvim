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

  cmd("HttpieEnvSelect", function()
    require("httpie.env").select()
  end, { desc = "Select active HTTPie environment" })

  cmd("HttpieEnvEdit", function()
    require("httpie.env").edit()
  end, { desc = "Edit HTTPie environment file" })

  cmd("HttpieEnvShow", function()
    require("httpie.env").show()
  end, { desc = "Show active HTTPie environment variables" })
end

return M
