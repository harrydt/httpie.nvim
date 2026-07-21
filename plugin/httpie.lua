if vim.g.loaded_httpie_nvim then return end
vim.g.loaded_httpie_nvim = true

-- Filetype detection is registered early so .http files work before setup()
vim.filetype.add({ extension = { http = "http" } })
