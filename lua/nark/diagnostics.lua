---@class Nark.Diagnostics
local M = {}

local config_mod = require("nark.config")
M.floats = {}
local ns = vim.api.nvim_create_namespace("nark")

local icons = {
  [vim.diagnostic.severity.ERROR] = " ",
  [vim.diagnostic.severity.WARN] = " ",
  [vim.diagnostic.severity.INFO] = " ",
  [vim.diagnostic.severity.HINT] = " ",
}

local hl_by_severity = {
  [vim.diagnostic.severity.ERROR] = "DiagnosticError",
  [vim.diagnostic.severity.WARN] = "DiagnosticWarn",
  [vim.diagnostic.severity.INFO] = "DiagnosticInfo",
  [vim.diagnostic.severity.HINT] = "DiagnosticHint",
}

--- Clear plugin highlights/namespace for a buffer
---@param buf number Buffer handle
local function clear(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
end

--- Format raw diagnostics into displayable items
---@param diags table[] List of diagnostics as returned by vim.diagnostic.get
---@param cfg Nark.ConfigDefaults|table|nil Optional config to control formatting
---@return table[] items List of formatted items with fields: text, severity, range, _ln, _col
local function format_diagnostics(diags, cfg)
  local out = {}
  local styles = (cfg and cfg.styles) or config_mod.defaults.styles
  local sev_names = {
    [vim.diagnostic.severity.ERROR] = "ERROR",
    [vim.diagnostic.severity.WARN] = "WARN",
    [vim.diagnostic.severity.INFO] = "INFO",
    [vim.diagnostic.severity.HINT] = "HINT",
  }
  for _, d in ipairs(diags) do
    -- only include diagnostics at or above the configured minimum severity
    if d.severity and d.severity <= (cfg and cfg.min_severity or vim.diagnostic.severity.HINT) then
      local msg = d.message or ""
      msg = msg:gsub("\n.*", "")
      local ln = 0
      local col = 0
      -- prefer normalized diagnostic fields from vim.diagnostic.get (lnum/col), fall back to LSP range
      if d.lnum or d.col then
        ln = (d.lnum or 0) + 1
        col = (d.col or 0) + 1
      elseif d.range and d.range.start then
        ln = (d.range.start.line or 0) + 1
        col = (d.range.start.character or 0) + 1
      end
      local sev_name = sev_names[d.severity] or ""
      local tpl = styles[sev_name]
      local text
      if tpl then
        text = tpl:gsub("{L}", tostring(ln)):gsub("{C}", tostring(col)):gsub("{M}", msg)
      else
        text = string.format("%d:%d %s%s", ln, col, (icons[d.severity] or ""), msg)
      end
      table.insert(out, { text = text, severity = d.severity, range = d.range, _ln = ln, _col = col })
    end
  end

  return out
end

--- Place diagnostics as virt_lines in the buffer
---@param buf number|nil Buffer handle (default: current buffer)
---@param cfg Nark.ConfigDefaults|table|nil Configuration used to filter/format diagnostics
---@return nil
function M.update(buf, cfg)
  buf = buf or vim.api.nvim_get_current_buf()
  cfg = cfg or config_mod.defaults

  clear(buf)

  local diags = vim.diagnostic.get(buf)
  if cfg.hide_underline_diagnostics then
    -- ensure diagnostics engine doesn't show underlines or virtual text
    vim.diagnostic.config({ virtual_text = false, underline = false })
  end
  -- optionally filter to diagnostics from the most-relevant attached LSP client
  if cfg.only_current_client then
    local clients = vim.lsp.get_clients({ bufnr = buf })
    if clients and #clients > 0 and diags then
      -- choose the client whose name appears most often in the diagnostics' source
      local counts = {}
      for _, d in ipairs(diags) do
        local src = d.source or ""
        counts[src] = (counts[src] or 0) + 1
      end
      local chosen_name
      local maxc = 0
      for _, c in ipairs(clients) do
        local n = counts[c.name] or 0
        if n > maxc then
          maxc = n
          chosen_name = c.name
        end
      end
      chosen_name = chosen_name or clients[1].name
      local filtered = {}
      for _, d in ipairs(diags) do
        if d.source == chosen_name then
          table.insert(filtered, d)
        end
      end
      diags = filtered
    end
  end
  if not diags or vim.tbl_isempty(diags) then
    -- close any existing floats when no diagnostics
    for _, f in pairs(M.floats) do
      if f and vim.api.nvim_win_is_valid(f.win) then
        pcall(vim.api.nvim_win_close, f.win, true)
      end
      if f and vim.api.nvim_buf_is_valid(f.buf) then
        pcall(vim.api.nvim_buf_delete, f.buf, { force = true })
      end
    end
    M.floats = {}
    return
  end

  local items = format_diagnostics(diags, cfg)
  if #items == 0 then
    return
  end

  local pos = cfg.position or config_mod.defaults.position
  local target_line
  if pos:match("^top") then
    target_line = vim.fn.line("w0") - 1
  else
    target_line = vim.fn.line("w$") - 1
  end

  local line_count = vim.api.nvim_buf_line_count(buf)
  if target_line < 0 then
    target_line = 0
  end
  if target_line > line_count - 1 then
    target_line = line_count - 1
  end

  -- create a simple floating window at the requested corner
  local function close_float(win)
    local f = M.floats[win]
    if f then
      if vim.api.nvim_win_is_valid(f.win) then
        pcall(vim.api.nvim_win_close, f.win, true)
      end
      if vim.api.nvim_buf_is_valid(f.buf) then
        pcall(vim.api.nvim_buf_delete, f.buf, { force = true })
      end
      M.floats[win] = nil
    end
  end

  local function open_or_update_float(win, lines, fcfg)
    fcfg = fcfg or config_mod.defaults
    local content_max_width = 0
    for _, l in ipairs(lines) do
      content_max_width = math.max(content_max_width, vim.fn.strdisplaywidth(l))
    end
    local max_items = fcfg.max_items or config_mod.defaults.max_items or 100
    local height = math.min(#lines, max_items)
    local width = math.min(content_max_width + 2, fcfg.max_width or 120)

    -- position relative to the editor to guarantee right alignment
    local ed_w = vim.o.columns
    local ed_h = vim.o.lines
    local margin = 2
    local anchor, row, col
    if fcfg.position == "top_right" then
      -- anchor at top-right corner of the float; set row using configured top_inset so float is inset lines from top
      anchor, row, col = "NE", (fcfg.top_inset or 0), ed_w - margin
    elseif fcfg.position == "top_left" then
      anchor, row, col = "NW", (fcfg.top_inset or 0), margin
    elseif fcfg.position == "bottom_right" then
      -- anchor at bottom-right so float's right edge is margin from editor right
      anchor, row, col = "SE", ed_h - margin, ed_w - margin
    else
      anchor, row, col = "SW", ed_h - height - margin, margin
    end

    local opts = {
      relative = "editor",
      anchor = anchor,
      row = row,
      col = col,
      width = width,
      height = height,
      style = "minimal",
      focusable = false,
      noautocmd = true,
    }

    -- apply optional border from config (false/nil means no border)
    if fcfg.border and fcfg.border ~= false then
      opts.border = fcfg.border
    end

    local f = M.floats[win]
    -- if an existing float exists but its height differs from desired, recreate it so size updates
    if f and vim.api.nvim_win_is_valid(f.win) and vim.api.nvim_buf_is_valid(f.buf) then
      local ok, cur_h = pcall(vim.api.nvim_win_get_height, f.win)
      if ok and cur_h ~= height then
        pcall(vim.api.nvim_win_close, f.win, true)
        pcall(vim.api.nvim_buf_delete, f.buf, { force = true })
        M.floats[win] = nil
        f = nil
      end
    end
    if
        not f
        or not vim.api.nvim_win_is_valid((f and f.win) or -1)
        or not vim.api.nvim_buf_is_valid((f and f.buf) or -1)
    then
      -- create new buffer
      local fbuf = vim.api.nvim_create_buf(false, true)
      -- set buffer-local option without deprecated API
      vim.bo[fbuf].bufhidden = "wipe"
      vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, lines)
      -- apply severity-based highlights (only for visible/capped items)
      vim.api.nvim_buf_clear_namespace(fbuf, ns, 0, -1)
      for i, it in ipairs(items) do
        if i > max_items then
          break
        end
        local hl = hl_by_severity[it.severity]
        if hl then
          pcall(vim.api.nvim_buf_add_highlight, fbuf, ns, hl, i - 1, 0, -1)
        end
      end

      local w = vim.api.nvim_open_win(fbuf, false, opts)
      -- set window-local options without deprecated API
      pcall(vim.api.nvim_win_call, w, function()
        vim.wo.winblend = 10
        vim.wo.wrap = false
      end)
      M.floats[win] = { buf = fbuf, win = w }
      return
    end

    -- update existing
    vim.api.nvim_buf_set_lines(f.buf, 0, -1, false, lines)
    -- apply severity-based highlights (only for visible/capped items)
    vim.api.nvim_buf_clear_namespace(f.buf, ns, 0, -1)
    for i, it in ipairs(items) do
      if i > max_items then
        break
      end
      local hl = hl_by_severity[it.severity]
      if hl then
        pcall(vim.api.nvim_buf_add_highlight, f.buf, ns, hl, i - 1, 0, -1)
      end
    end
    -- update full config so position and anchor are kept consistent
    if fcfg.border and fcfg.border ~= false then
      opts.border = fcfg.border
    else
      opts.border = nil
    end
    pcall(vim.api.nvim_win_set_config, f.win, opts)
  end

  -- sort by buffer position (line, col) then severity for natural ordering
  table.sort(items, function(a, b)
    if a._ln and b._ln and (a._ln ~= b._ln) then
      return a._ln < b._ln
    end
    if a._col and b._col and (a._col ~= b._col) then
      return a._col < b._col
    end
    if a.severity ~= b.severity then
      return (a.severity or 99) < (b.severity or 99)
    end
    return a.text < b.text
  end)

  -- cap items to configured maximum
  local max_items = cfg.max_items or config_mod.defaults.max_items or 100
  local capped = {}
  for i = 1, math.min(#items, max_items) do
    table.insert(capped, items[i])
  end

  -- prepare lines for the float
  local float_lines = {}
  for _, it in ipairs(capped) do
    table.insert(float_lines, it.text)
  end

  -- reuse a single float (keyed by 0) so updates resize/reposition correctly
  local win = 0
  if #float_lines == 0 then
    close_float(win)
  else
    open_or_update_float(win, float_lines, cfg)
  end
end

--- Setup diagnostics rendering and autocmds.
---@param opts Nark.ConfigDefaults|table|nil Configuration overrides
---@return nil
function M.setup(opts)
  local cfg = config_mod.normalize(opts)
  -- configure diagnostics engine according to user choices
  if cfg.hide_underline_diagnostics then
    vim.diagnostic.config({ virtual_text = false, underline = false })
  else
    -- keep virtual_text off (nark uses its own floats) but preserve underline unless user disabled it
    vim.diagnostic.config({ virtual_text = false })
  end

  -- ensure LSP handlers also don't render virtual text and respect underline choice
  local default_publish = vim.lsp.handlers["textDocument/publishDiagnostics"]
  vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
    config = config or {}
    config.virtual_text = false
    if cfg.hide_underline_diagnostics then
      config.underline = false
    end
    return default_publish(err, result, ctx, config)
  end

  local group = vim.api.nvim_create_augroup("nark", { clear = true })

  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = function(ev)
      M.update(ev.buf, cfg)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function()
      M.update(vim.api.nvim_get_current_buf(), cfg)
    end,
  })

  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function()
      M.update(vim.api.nvim_get_current_buf(), cfg)
    end,
  })

  if cfg.hide_on_insert then
    vim.api.nvim_create_autocmd({ "InsertEnter" }, {
      group = group,
      callback = function()
        -- close floats while inserting
        for _, f in pairs(M.floats) do
          if f and vim.api.nvim_win_is_valid(f.win) then
            pcall(vim.api.nvim_win_close, f.win, true)
          end
        end
      end,
    })
    vim.api.nvim_create_autocmd({ "InsertLeave" }, {
      group = group,
      callback = function()
        -- reapply diagnostics config to restore underline after other plugins/LSP may have changed it
        vim.diagnostic.config({ virtual_text = false, underline = not cfg.hide_underline_diagnostics })
        M.update(vim.api.nvim_get_current_buf(), cfg)
      end,
    })
  end

  -- initial render
  M.update(vim.api.nvim_get_current_buf(), cfg)
end

return M
