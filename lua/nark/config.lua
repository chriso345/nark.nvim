---@class Nark.ConfigDefaults
---@field position "top_right"|"top_left"|"bottom_right"|"bottom_left" Position of the notifications
---@field min_severity integer Minimum severity level to display; one of vim.diagnostic.severity
---@field max_width integer Maximum width (columns) of the diagnostics float
---@field inset integer Number of lines to inset the float from the top when positioned top_*
---@field border boolean|nil Border style for diagnostics float; false/nil disables border, or provide an nvim_open_win border
---@field max_items integer Maximum number of diagnostics to display in the float
---@field hide_on_insert boolean If true, close floats on InsertEnter
---@field hide_underline_diagnostics boolean If true, disables underline diagnostics in Neovim
---@field styles table<string, string> Mapping of severity names to format templates

local M = {}

---@type Nark.ConfigDefaults
M.defaults = {
  -- position: where to place the diagnostics float on the editor.
  -- Allowed values:
  --   "top_right"    - anchor float in the top-right corner of the editor
  --   "top_left"     - anchor float in the top-left corner
  --   "bottom_right" - anchor float in the bottom-right corner
  --   "bottom_left"  - anchor float in the bottom-left corner
  -- Example: position = "bottom_left"
  position = "top_right",

  -- min_severity: filter diagnostics by severity. Use values from vim.diagnostic.severity.
  -- Numeric mapping (lower is more severe):
  --   vim.diagnostic.severity.ERROR = 1
  --   vim.diagnostic.severity.WARN  = 2
  --   vim.diagnostic.severity.INFO  = 3
  --   vim.diagnostic.severity.HINT  = 4
  -- Only diagnostics with severity <= min_severity will be shown.
  -- Example: to show only ERROR and WARN, set `min_severity = vim.diagnostic.severity.WARN`.
  min_severity = vim.diagnostic.severity.HINT,

  -- max_width: maximum width (in columns) for the diagnostics float. Integer > 0.
  -- Long lines are truncated to fit this width.
  -- Example: max_width = 80
  max_width = 30,

  -- top_inset: when using top_* positions, inset the float by this many editor lines from the top.
  -- Useful to avoid covering a global statusline/tabline. Integer >= 0.
  -- Example: top_inset = 2
  inset = 0,

  -- border: border style for the float (passed to nvim_open_win).
  -- Allowed values:
  --   false or nil   - no border
  --   string         - named border style ("single", "rounded", etc.)
  --   table          - explicit border spec compatible with nvim_open_win
  -- Example: border = "rounded"
  border = false,

  -- max_items: maximum number of diagnostics to show in the float. Integer > 0.
  -- When the number of diagnostics exceeds this, the list is truncated.
  -- Example: max_items = 200
  max_items = 100,

  -- hide_on_insert: if true, close/hide the diagnostics float while in Insert mode.
  -- Set to false to keep the float visible while inserting text.
  -- Example: hide_on_insert = false
  hide_on_insert = true,

  -- hide_underline_diagnostics: when true, tell Neovim and the LSP handlers to disable
  -- underline diagnostics (the squiggly/underline under text). When false, underline is preserved.
  -- This only controls the engine's underline output; nark still renders diagnostics in a float.
  -- Example: hide_underline_diagnostics = true
  hide_underline_diagnostics = false,

  -- styles: mapping from severity name (ERROR/WARN/INFO/HINT) to a string template used
  -- to format each float line. Template tokens:
  --   {L} - line number
  --   {C} - column number
  --   {M} - diagnostic message
  -- Examples:
  --   ERROR = "{L}:{C} ERROR {M}"
  styles = {
    HINT = " {M}",
    INFO = " {M}",
    WARN = " {M}",
    ERROR = " {M}",
  },
}

--- Merge user opts with defaults and return a normalized config table
---@param opts table|nil Partial configuration to override defaults.
---@return Nark.ConfigDefaults normalized configuration table
function M.normalize(opts)
  return vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
