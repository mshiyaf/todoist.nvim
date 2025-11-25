# todoist.nvim

A minimal Todoist client for Neovim. Fetch, add, and complete tasks from Todoist without leaving your editor.

## Features
- Secure token handling (env var or permissioned file with `0600` under `stdpath('data')/todoist/token`).
- Async API calls via `curl`; no external Lua dependencies.
- Floating window task viewer with refresh and complete shortcuts.
- Commands to add tasks, list open tasks, and close them from Neovim.

## Requirements
- Neovim 0.8+ (uses `vim.fn.jobstart`).
- `curl` available in `PATH` (used for API requests).

## Installation
Lazy.nvim example:

```lua
{
  "mshiyaf/todoist.nvim",
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
- `:TodoistLogin` – prompt for an API token and save it securely.
- `:TodoistLogout` – delete the saved token file.
- `:TodoistTasks [project_id]` – open a floating list of your open tasks (filtered by optional project id).
- `:TodoistAdd` – interactive prompts to create a new task (uses configured default project/priority).
- `:TodoistComplete <id>` – close a task by id.

In the task window:
- `r` refresh
- `c` or `<CR>` close the task under the cursor
- `q` close the window

## Configuration
All options are passed to `require("todoist").setup({ ... })`:

- `default_project` (number) – default project id for new tasks and list filters.
- `default_priority` (1-4) – default priority for created tasks.
- `curl_bin` (string) – override the curl binary path.
- `notify` (function) – custom notification handler (defaults to `vim.notify`).
- `data_dir` (string) – where the token file is stored (defaults to `stdpath('data')/todoist`).
- `api_base` (string) – Todoist REST base URL (defaults to `https://api.todoist.com/rest/v2`).

## Security Notes
- Tokens are never echoed; `:TodoistLogin` uses `vim.ui.input` with `secret=true`.
- Saved tokens are written with `0600` permissions under `data_dir` and can be removed via `:TodoistLogout`.
- If `TODOIST_API_TOKEN` is set, the plugin never reads the saved token file.

## Limitations
- Only open tasks are shown; completed history is not fetched.
- Requires `curl`; no HTTP fallback is implemented.

## License
MIT
