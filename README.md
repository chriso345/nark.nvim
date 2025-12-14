# nark.nvim

`nark.nvim` is a small Neovim utility that renders LSP/diagnostic messages in a compact floating panel anchored to a corner of the editor. It does not modify buffer text; instead it collects diagnostics and displays them in a single, configurable float that updates automatically.

---

## Features

* Show aggregated diagnostics in a corner floating window (top_right, top_left, bottom_right, bottom_left).
* Filter diagnostics by severity and limit the number of displayed items.
* Optionally only show diagnostics from the most-relevant attached LSP client.
* Optional automatic hiding of floats during Insert mode.
* Configurable line formatting templates and maximum float width.
* Automatic updates on DiagnosticChanged, BufEnter, WinEnter and WinScrolled events.

---

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "chriso345/nark.nvim",
  opts = {
    position = "top_right",                          -- one of: top_right, top_left, bottom_right, bottom_left
    min_severity = diag.severity.HINT,               -- minimal severity to display
    max_width = 30,                                  -- maximum float content width (columns)
    inset = 0,                                       -- inset lines from the border of the window
    border = false,                                  -- border style (see :h nvim_open_win)
    max_items = 100,                                 -- cap number of shown diagnostics
    hide_on_insert = true,                           -- close floats while in Insert mode
    hide_underline_diagnostics = false,              -- disable LSP underline diagnostics when true
    styles = {                                       -- format templates per severity
      HINT = " {M}",
      INFO = " {M}",
      WARN = " {M}",
      ERROR = " {M}",
    },
  },
}
```

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
