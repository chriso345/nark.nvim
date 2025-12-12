---@class Nark
local M = {}

local config_mod = require("nark.config")
local diagnostics = require("nark.diagnostics")

--- Setup Nark plugin.
---@param opts Nark.ConfigDefaults|table|nil Configuration overrides (see nark.config M.defaults)
---@return nil
function M.setup(opts)
  opts = config_mod.normalize(opts)
  diagnostics.setup(opts)
end

return M
