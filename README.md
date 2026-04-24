# terms.nvim

Run any CLI in Neovim terminal windows with named, persistent sessions.

## Example

```lua
local terms = require("terms")

vim.keymap.set("n", "<C-1>", function()
    terms.toggle({ cmd = "claude", name = "claude" })
end)

vim.keymap.set("x", "<C-1>", function()
    terms.send_selection({ cmd = "claude", name = "claude" })
end)

vim.keymap.set("n", "<C-2>", function()
    terms.toggle({ cmd = "lazygit", name = "lazygit" })
end)

vim.keymap.set("n", "<C-3>", function()
    terms.toggle({ cmd = "zsh", name = "zsh" })
end)
```

## Configuration

```lua
require("terms").setup({
  width = 0.9,        -- fraction of editor width (float/vsplit)
  height = 0.9,       -- fraction of editor height (float/hsplit)
  position = "float", -- "float" | "vsplit" | "hsplit"
  close = "<C-q>",    -- buffer-local key to hide the terminal window (set to false to disable)
})
```

## Lua API

All functions take an options table. `name` is always required and identifies the session. The window title is the `name`.

```lua
local t = require("terms")

-- create session if missing, hide/show if exists,
-- recreate if the same name is toggled with a different cmd
t.toggle({ cmd = "claude", name = "claude terminal" })

-- force-recreate session
t.new({ cmd = "claude", name = "claude terminal" })

-- kill and remove session
t.delete({ name = "claude terminal" })

-- send text (creates session if missing)
t.send({ text = "hello\n", cmd = "claude", name = "claude terminal" })

-- send current visual selection (creates session if missing)
-- pass include_context = false to send raw selection without file path / fence
-- t.send_selection({ cmd = "claude", name = "claude", include_context = false })
t.send_selection({ cmd = "claude", name = "claude terminal" })
```

