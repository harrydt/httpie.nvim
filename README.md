# httpie.nvim

A Neovim plugin for [HTTPie](https://httpie.io/cli) — run HTTP requests and manage collections without leaving your editor.

## Requirements

- Neovim 0.9+
- [HTTPie](https://httpie.io/cli) (`brew install httpie`)

## Installation

```lua
-- lazy.nvim
{ "harrydt/httpie.nvim", config = function()
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

`{{VAR}}` placeholders in the URL, headers, or body are substituted from OS environment variables (`export BASE_URL=...`, `export TOKEN=...` in your shell). If a variable isn't set, the placeholder is left as-is.

### Importing httpie commands

Paste an `http` CLI command (copied from your terminal) into a `.http` file, select it (visual mode), and run `:HttpieImport` to convert it into a request block in place:

```
http POST https://api.example.com/users Authorization:"Bearer abc123" name=Alice age:=30
```

becomes:

```http
###
POST https://api.example.com/users
Authorization: Bearer abc123
Content-Type: application/json

{"age": 30, "name": "Alice"}
```

Supported: methods, URLs, headers (`Name:value`), JSON body fields (`key=value`, `key:=value` for raw JSON), query params (`key==value`), basic auth (`-a user:pass`), and form-encoded bodies (`-f`). Anything else (file uploads, sessions, etc.) is left as a `# NOTE:` comment instead of being silently dropped.

Shell-style `$VAR` / `${VAR}` references left over from the pasted command (e.g. `Authorization:"Bearer $TOKEN"`) are converted to `{{VAR}}`, so they resolve from your OS environment instead of staying as dead text.

Run `:HttpieExport` on a request block to go the other way: it builds the equivalent `http` CLI command and copies it to your system clipboard, ready to paste into a terminal. `{{VAR}}` placeholders are converted back to `$VAR`, so the command never contains a resolved secret — the value is only filled in by your shell when you actually run it. If the request has a body, it's exported as `echo '{...}' | http POST ...` to match the common convention (and mirrors what `:HttpieImport` accepts). A plain `Content-Type: application/json` header is omitted from the export, since httpie sets that automatically whenever a body is present — any other Content-Type is kept.

### Collections

Saved collections are `.http` files stored in `~/.local/share/nvim/httpie-nvim/`.

| Command | Action |
|---|---|
| `:HttpieNew [name]` | Create a new collection |
| `:HttpieOpen` | Browse and open a saved collection |
| `:HttpieSave` | Append the request at cursor to a collection |
| `:HttpieRun` | Run the request at cursor |
| `:HttpieImport` | Convert a selected httpie CLI command into a request block |
| `:HttpieExport` | Copy the request at cursor as an httpie CLI command |
| `:HttpieClose` | Close the current `.http` buffer and return to where it was opened from |

`:HttpieClose` refuses to close if the buffer has unsaved changes (save with `:w` first, or force with `:bd!`), and does nothing if the current buffer isn't an `.http` file.

### Sensitive headers

The command echoed at the top of the output window (`# $ http ...`) masks known sensitive header values as `***` — `Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, `X-Auth-Token`, and `Proxy-Authorization`. The actual request still sends the real, substituted value; only the echoed line is masked. This list isn't currently configurable, and request bodies aren't masked at all.

## Configuration

```lua
require("httpie").setup({
  binary    = "http",                              -- path to httpie binary
  storage_dir = vim.fn.stdpath("data") .. "/httpie-nvim", -- where collections live
  output = {
    split = "vertical",  -- "vertical" | "horizontal" | "float"
    size  = 80,
  },
})
```
