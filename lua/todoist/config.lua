local M = {}

local defaults = {
  api_base = "https://api.todoist.com/rest/v2",
  data_dir = vim.fn.stdpath("data") .. "/todoist",
  token = nil,
  default_project = nil,
  default_priority = nil,
  curl_bin = "curl",
  notify = vim.notify,
  keymaps = {
    enable = true,
    mappings = {
      open_tasks = "<leader>tt",
      open_today = "<leader>ty",
      add_task = "<leader>ta",
      login = "<leader>tl",
      logout = "<leader>tL",
    }
  },
  fzf = {
    winopts = {
      height = 0.85,
      width = 0.80,
      preview = {
        layout = "vertical",
        vertical = "down:45%",
      },
    },
    keybinds = {
      complete = "default",
      view_details = "ctrl-d",
      edit = "ctrl-e",
      delete = "ctrl-x",
      refresh = "ctrl-r",
    },
  },
  task_format = {
    show_id = true,
    show_priority = true,
    show_due_date = true,
  },
  today_view_ui = "custom", -- "custom" or "fzf"
  custom_ui = {
    split_ratio = 0.6,      -- List window width percentage
    enable_fuzzy_search = true,
    show_priority_headers = true,
    auto_preview = true,
    highlights = {
      priority_4 = { fg = "#ff5555", bold = true },
      priority_3 = { fg = "#ffb86c", bold = true },
      priority_2 = { fg = "#8be9fd" },
      priority_1 = { fg = "#6272a4" },
      header = { fg = "#f8f8f2", bold = true },
      project = { fg = "#50fa7b", italic = true },
      due_time = { fg = "#ff79c6" },
    },
  },
  loader = {
    enabled = true,
    spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    frame_delay = 80, -- milliseconds
    messages = {
      loading_tasks = "Loading tasks...",
      refreshing = "Refreshing tasks...",
      loading_today = "Loading today's tasks...",
    },
  },
}

local state = vim.deepcopy(defaults)

function M.setup(opts)
  if opts then
    state = vim.tbl_deep_extend("force", state, opts)
  end
end

function M.get()
  return state
end

function M.reset()
  state = vim.deepcopy(defaults)
end

return M
