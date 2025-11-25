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
