-- Loads the plugin and keymaps
if vim.g.loaded_nark then
  return
end
vim.g.loaded_nark = true

---@type Nark
local _nark = require("nark")
_nark.setup()
