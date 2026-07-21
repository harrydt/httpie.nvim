-- Buffer settings for .http request files
vim.opt_local.commentstring = "# %s"
vim.opt_local.wrap = false

-- Fold on ### separators so large collections stay navigable
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "getline(v:lnum)=~'^###'?'>1':'='"
vim.opt_local.foldenable = false -- open by default
