# httpie.nvim

A Neovim plugin for [HTTPie](https://httpie.io/cli) — run HTTP requests, manage collections, and switch environments without leaving your editor.

## Requirements

- Neovim 0.9+
- [HTTPie](https://httpie.io/cli) (`brew install httpie`)

## Installation

```lua
-- lazy.nvim
{ dir = "~/code/httpie.nvim", config = function()
  require("httpie").setup()
end }
```

## Usage

### Request files

Create a `.http` file (`:HttpieNew myapi`) and write requests separated by `###`:

```http
### Get users
GET {{BASE_URL}}/users
Authorization: Bearer {{TOKEN}}
Accept: application/json


### Create user
POST {{BASE_URL}}/users
Content-Type: application/json

{"name": "Alice", "email": "alice@example.com"}
```

Run `:HttpieRun` on any request block to execute it. The response appears in a vertical split.

### Collections

Saved collections are `.http` files stored in `~/.local/share/nvim/httpie-nvim/`.

| Command | Action |
|---|---|
| `:HttpieNew [name]` | Create a new collection |
| `:HttpieOpen` | Browse and open a saved collection |
| `:HttpieSave` | Append the request at cursor to a collection |
| `:HttpieRun` | Run the request at cursor (also `<CR>`) |

### Environments

Create an `httpie-env.json` file in your project root:

```json
{
  "dev":  { "BASE_URL": "https://dev.api.com",  "TOKEN": "dev-token"  },
  "prod": { "BASE_URL": "https://api.com",       "TOKEN": "prod-token" }
}
```

`{{VAR}}` placeholders in URLs, headers, and bodies are substituted from the active environment.

| Command | Action |
|---|---|
| `:HttpieEnvSelect` | Pick the active environment |
| `:HttpieEnvEdit` | Open `httpie-env.json` in the current directory |
| `:HttpieEnvShow` | Print the active environment's variables |

## Configuration

```lua
require("httpie").setup({
  binary    = "http",                              -- path to httpie binary
  storage_dir = vim.fn.stdpath("data") .. "/httpie-nvim", -- where collections live
  env_file  = "httpie-env.json",                  -- env file name (looked up in cwd)
  output = {
    split = "vertical",  -- "vertical" | "horizontal" | "float"
    size  = 80,
  },
})
```
