# httpie.nvim

A Neovim plugin for [HTTPie](https://httpie.io/cli) — run HTTP requests and manage collections without leaving your editor.

## Requirements

- Neovim 0.9+
- [HTTPie](https://httpie.io/cli) (`brew install httpie`)

## Installation

```lua
-- lazy.nvim
{
  "harrydt/httpie.nvim",
  config = function()
    require("httpie").setup()
  end,
}
```

## Usage

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

`{{VAR}}` placeholders are substituted from OS environment variables (`export BASE_URL=...`).

| Command | Action |
|---|---|
| `:HttpieNew [name]` | Create a new collection |
| `:HttpieOpen` | Browse and open a saved collection |
| `:HttpieSave` | Append the request at cursor to a collection |
| `:HttpieRun` | Run the request at cursor |
| `:HttpieClose` | Close the current `.http` buffer and return to where it was opened from |
| `:HttpieImport` | Convert a selected httpie CLI command into a request block |
| `:HttpieExport` | Copy the request at cursor as an httpie CLI command |

Collections are `.http` files stored in `~/.local/share/nvim/httpie-nvim/`.

`:HttpieImport` — paste an `http` CLI command into a `.http` file, select it (visual mode), and run `:HttpieImport`:

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

`:HttpieExport` goes the other way: builds the equivalent `http` CLI command for the request at cursor and copies it to your system clipboard.

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

## FAQ

**What httpie syntax does `:HttpieImport` support?**

- Methods and URLs
- Headers (`Name:value`)
- JSON body fields (`key=value`, `key:=value` for raw JSON)
- Query params (`key==value`)
- Basic auth (`-a user:pass`)
- Form-encoded bodies (`-f`)
- Piped bodies (`echo '{...}' | http POST ...`)
- Anything else (file uploads, sessions, etc.) is left as a `# NOTE:` comment instead of being silently dropped

**What happens to `$VAR` / `${VAR}` in an imported command?**

- They're converted to `{{VAR}}`
- A header like `Authorization:"Bearer $TOKEN"` resolves from your OS environment instead of staying as dead text

**What does `:HttpieExport` produce, exactly?**

- `{{VAR}}` placeholders are converted back to `$VAR`, so the exported command never contains a resolved secret — the value is only filled in by your shell when you run it
- If the request has a body, it's exported as `echo '{...}' | http POST ...`
- A plain `Content-Type: application/json` header is omitted, since httpie sets that automatically whenever a body is present
- Any other `Content-Type` is kept

**Are secrets ever shown in the output window?**

- The command echoed at the top of the output window (`# $ http ...`) masks known sensitive header values as `***` — `Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, `X-Auth-Token`, and `Proxy-Authorization`
- The actual request still sends the real, substituted value; only the echoed line is masked
- This list isn't currently configurable
- Request bodies aren't masked at all

**What does `:HttpieClose` do if I have unsaved changes?**

- It refuses to close (save with `:w` first, or force with `:bd!`)
- It also does nothing if the current buffer isn't an `.http` file
