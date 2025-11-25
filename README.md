# todoist.nvim

A powerful Todoist client for Neovim with fuzzy search powered by fzf-lua. Manage your tasks with full CRUD operations without leaving your editor.

## Features
- **fzf-lua integration** for powerful fuzzy search and filtering
- **Full task management**: View, create, edit, complete, and delete tasks
- **Advanced filtering**: Filter by project, priority, and due date
- **Colorful Today view**: Prioritized Today list with project tags and highlights
- **Live preview**: See full task details in real-time preview pane
- **Secure token handling** (env var or permissioned file with `0600` under `stdpath('data')/todoist/token`)
- **Async API calls** via `curl` with no external dependencies

## Requirements
- Neovim 0.8+ (uses `vim.fn.jobstart`)
- `curl` available in `PATH` (used for API requests)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua) plugin (required dependency)

## Installation
Lazy.nvim example:

```lua
{
  "mshiyaf/todoist.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("todoist").setup({
      -- optional overrides
      default_project = nil, -- default project id
      default_priority = nil, -- 1-4 per Todoist docs
    })
  end,
}
```

Packer example:

```lua
use({
  "mshiyaf/todoist.nvim",
  requires = { "ibhagwan/fzf-lua" },
  config = function()
    require("todoist").setup()
  end,
})
```

## Authentication
1. Prefer an environment variable (no file writes): `export TODOIST_API_TOKEN=...`.
2. Or run `:TodoistLogin` inside Neovim and paste your API token. The plugin stores it at `stdpath('data')/todoist/token` with `0600` permissions.
3. Remove saved credentials with `:TodoistLogout`.

## Commands
- `:TodoistLogin` – prompt for an API token and save it securely
- `:TodoistLogout` – delete the saved token file
- `:TodoistTasks [project_id]` – open fzf-lua picker with your tasks (filtered by optional project id)
- `:TodoistToday` – colorized Today view, sorted by priority then project
- `:TodoistAdd` – interactive prompts to create a new task (uses configured default project/priority)
- `:TodoistComplete <id>` – close a task by id

## Picker Actions

When the fzf-lua picker is open, you can use these keybindings:

- `Enter` – Complete the selected task
- `Ctrl-d` – View full task details in a popup window
- `Ctrl-e` – Edit task (content, due date, or priority)
- `Ctrl-x` – Delete task (with confirmation)
- `Ctrl-r` – Refresh task list
- Type to fuzzy search across all task fields

## Keybindings

By default, todoist.nvim sets up the following global keymaps:

- `<leader>tt` – Open Todoist tasks window
- `<leader>ty` – Open Todoist Today view (priority + project ordering)
- `<leader>ta` – Add a new Todoist task
- `<leader>tl` – Login to Todoist
- `<leader>tL` – Logout from Todoist

(In LazyVim, `<leader>` is `<space>`, so `<leader>tt` is `<space>tt`)

In the fzf-lua picker:
- `Enter` – Complete task
- `Ctrl-d` – View full task details
- `Ctrl-e` – Edit task (content/due/priority)
- `Ctrl-x` – Delete task
- `Ctrl-r` – Refresh task list

### Today View

Use `:TodoistToday` (or `<leader>ty`) for a Today-only picker. Tasks are sorted by priority then project, and entries show colored priority badges plus project tags. Shortcuts match the main fzf view.

### Customizing Keymaps

Disable automatic keymaps if you prefer manual setup:

```lua
require("todoist").setup({
  keymaps = { enable = false }
})
```

Customize specific keymaps:

```lua
require("todoist").setup({
  keymaps = {
    mappings = {
      open_tasks = "<leader>ot",  -- Custom mapping
      open_today = "<leader>oy",
      add_task = "<leader>oa",
      login = false,              -- Disable this keymap
      logout = false,
    }
  }
})
```

### LazyVim Integration

The plugin automatically integrates with which-key. Press `<leader>t` to see available Todoist commands in the which-key popup.

For better group naming in which-key, add this to your config:

```lua
{
  "mshiyaf/todoist.nvim",
  config = function()
    require("todoist").setup()

    -- Optional: Add group name for which-key
    require("which-key").add({
      { "<leader>t", group = "todoist" }
    })
  end,
}
```

## Configuration
All options are passed to `require("todoist").setup({ ... })`:

- `default_project` (number) – default project id for new tasks and list filters
- `default_priority` (1-4) – default priority for created tasks
- `curl_bin` (string) – override the curl binary path
- `notify` (function) – custom notification handler (defaults to `vim.notify`)
- `data_dir` (string) – where the token file is stored (defaults to `stdpath('data')/todoist`)
- `api_base` (string) – Todoist REST base URL (defaults to `https://api.todoist.com/rest/v2`)
- **`keymaps`** (table) – keymap configuration:
  - `enable` (boolean) – enable/disable automatic keymaps (default: `true`)
  - `mappings` (table) – custom keymap definitions:
    - `open_tasks` (string|false) – open tasks window (default: `"<leader>tt"`)
    - `open_today` (string|false) – open Today view (default: `"<leader>ty"`)
    - `add_task` (string|false) – add task (default: `"<leader>ta"`)
    - `login` (string|false) – login (default: `"<leader>tl"`)
    - `logout` (string|false) – logout (default: `"<leader>tL"`)
- **`fzf`** (table) – fzf-lua picker configuration:
  - `winopts` (table) – window options (height, width, preview layout)
  - `keybinds` (table) – action keybindings:
    - `complete` (string) – complete task (default: `"default"` = Enter)
    - `view_details` (string) – view details (default: `"ctrl-d"`)
    - `edit` (string) – edit task (default: `"ctrl-e"`)
    - `delete` (string) – delete task (default: `"ctrl-x"`)
    - `refresh` (string) – refresh list (default: `"ctrl-r"`)
- **`task_format`** (table) – task display format:
  - `show_id` (boolean) – show task ID (default: `true`)
  - `show_priority` (boolean) – show priority (default: `true`)
  - `show_due_date` (boolean) – show due date (default: `true`)

### Example Configuration

```lua
require("todoist").setup({
  default_project = 123456789,
  default_priority = 2,
  fzf = {
    winopts = {
      height = 0.90,
      width = 0.85,
    },
    keybinds = {
      complete = "default",
      view_details = "ctrl-d",
      edit = "ctrl-e",
      delete = "ctrl-x",
      refresh = "ctrl-r",
    },
  },
})
```

## Security Notes
- Tokens are never echoed; `:TodoistLogin` uses `vim.ui.input` with `secret=true`.
- Saved tokens are written with `0600` permissions under `data_dir` and can be removed via `:TodoistLogout`.
- If `TODOIST_API_TOKEN` is set, the plugin never reads the saved token file.

## Limitations
- Only open tasks are shown; completed history is not fetched.
- Requires `curl`; no HTTP fallback is implemented.

## License
MIT
